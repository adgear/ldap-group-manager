# frozen_string_literal: true

require_relative('config')
require_relative('logging')
require_relative('ldap')
require_relative('utils')
require_relative('version')
require('hashdiff')
require('thor')

# AdGear
# Top level container
# @since 0.1.0
module AdGear
  # Infrastructure
  # Container within the AdGear space for infrastructure related tools.
  # @since 0.1.0
  module Infrastructure
    # GroupManager
    # A Ruby gem that pushes group memberships to LDAP.
    # @since 0.1.0
    module GroupManager
      # App
      # The top of stack abstraction for this application.
      # Read through the code to check the sequence of events.
      # @since 0.1.0
      class App < Thor
        include AdGear::Infrastructure::GroupManager::Config
        include AdGear::Infrastructure::GroupManager::Logging
        include AdGear::Infrastructure::GroupManager::LDAP
        include AdGear::Infrastructure::GroupManager::Utils
        include AdGear::Infrastructure::GroupManager::Version

        package_name 'groupmanager'

        map %w[--version -v] => :print_version

        # Displays the gem's version when invoked in the CLI.
        # @since 0.1.0
        desc '--version, -v', 'print the version'
        def print_version
          puts GEM_VERSION
        end

        class_option :verify_users, desc: 'Verifies that locally defined users exist remotely', type: :boolean

        desc 'diff', 'displays the difference between local and remote'
        # Displays the difference between local and remote.
        # @since 0.1.0
        def diff
          # get all local groups
          Log.info('Compiling all local groups')
          local_groups = Config.list_all_groups
          local_groups.each { |i| local_groups[i[0]] = Utils.symbolify_all_keys(i[1]) }
          local_groups = Utils.sort_member(local_groups)
          Log.debug(msg: 'local groups', local_groups: local_groups)

          Log.info('Compiling local users')
          users = Config.list_users
          Log.debug(msg: 'users', users: users)

          # get all local users and check if they exist remotely
          if options[:verify_users]
            Log.info("Verifying #{users.length} local users against remote")
            users.each { |dn| LDAP.item_exists?(dn) ? Log.debug("#{dn} exists") : raise("#{dn} does not exist") }
          end

          # get all remote groups
          Log.info('Compiling remote groups')
          remote_groups = LDAP.list_all_groups
          remote_groups = Utils.symbolify_all_keys(remote_groups)
          remote_groups = Utils.sort_member(remote_groups)
          Log.debug(msg: 'remote groups', remote_groups: remote_groups)

          ops_to_perform = Utils.create_ops_list(local_groups, remote_groups)
          Log.info(msg: 'Operations to perform', operations: ops_to_perform)
          ops_to_perform
        end

        desc 'apply', 'applies changes to remote'
        # Applies remote changes
        # @since 0.1.0
        def apply
          ops_to_perform = diff
          Log.info("Creating #{ops_to_perform[:create].length} new entities")
          ops_to_perform[:create].each do |cn|
            LDAP.set_item(
              :create,
              ["cn=#{cn}", Utils.find_ou(cn), GLOBAL_CONFIG['treebase']].join(', ')
            )
          end

          Log.info("Applying #{ops_to_perform[:modify].length} modifications to existing items")
          ops_to_perform[:modify].each do |i|
            LDAP.set_item(
              :modify, ["cn=#{i[:cn]}",
                        Utils.find_ou(i[:cn]),
                        GLOBAL_CONFIG['treebase']].join(', '), i[:attrib], i[:value]
                      )
          end

          if ops_to_perform[:delete]
            Log.info("Removing #{ops_to_perform[:delete].length} deprecated items")

            items_to_delete = ops_to_perform[:delete].map do |i|
              treebase = GLOBAL_CONFIG['treebase']

              filter = Net::LDAP::Filter.construct("CN=#{i}*")

              target = nil
              Binder.search(base: treebase, filter: filter).each do |entry|
                next unless /^CN=#{i},OU=/ =~ entry.dn
                target = entry.dn
              end
              target
            end

            items_to_delete.each do |i|
              LDAP.delete_item(i)
              Log.debug(Binder.get_operation_result)
            end
          end

          Log.info('done')

          exit(0)
        end
      end
    end
  end
end
