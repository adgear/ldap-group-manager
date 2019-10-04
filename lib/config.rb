# The global config instance.
# @since 0.1.0
module AdGear
  module Infrastructure
    module GroupManager
      module Config
        require_relative('logging')
        require('date')
        require('yaml')

        include AdGear::Infrastructure::GroupManager::Logging

        # The global config instance
        # rubocop:disable Style/MutableConstant
        GLOBAL_CONFIG = {
          data: {
            locations: {},
            organizational: {},
            functional: {},
            permissions: {}
          },
          today: DateTime.now
        }

        GLOBAL_CONFIG[:user_dn] = ENV['AG_USER_DN']
        GLOBAL_CONFIG[:password] = ENV['AG_PASSWORD']
        GLOBAL_CONFIG[:ldap_host] = ENV['AG_LDAP_HOST']
        GLOBAL_CONFIG[:treebase] = ENV['AG_TREEBASE']
        GLOBAL_CONFIG[:local_state] = ENV['AG_LOCAL_STATE'] || Dir.pwd
        GLOBAL_CONFIG[:settle_sleep] = Integer(ENV['AG_SETTLE_SLEEP'] || 15)

        GLOBAL_CONFIG.freeze
        # rubocop:enable Style/MutableConstant

        config_files = Dir.glob(File.join(GLOBAL_CONFIG[:local_state], '**/*.{yaml,yml}'))
        Log.trace(config_files)
        Log.fatal('No configuration files detected') if config_files.empty?

        config_files.each do |file|
          Log.debug("loading #{file}")
          parts = file.split('/').reject(&:empty?)
          target = parts[parts.length - 2]
          Log.debug("target: #{target}")
          data = YAML.safe_load(File.read(file)) || {}

          GLOBAL_CONFIG[:data][target.to_sym].merge!(data)

          # Here we resolve time constraints
          GLOBAL_CONFIG[:data].each do |tl, gs|
            gs.each do |k, v|
              next if v.nil?
              next unless v.key?('member')
              next if v['member'].nil?

              v['member'].each do |m|
                next if u.is_a?(String)

                if u.is_a?(Hash)
                  today = GLOBAL_CONFIG[:today]

                  too_early = false
                  if u.key?('not_before')
                    too_early = today < DateTime.parse(u['not_before'])
                  end

                  debug_message = {
                    msg: 'Encountered time-bound member',
                    member: m,
                    top_level: tl,
                    group: k,
                    too_early: too_early
                  }

                  if too_early
                    debug_message[:action] = 'ignore'
                    Log.info(debug_message)
                  else
                    debug_message[:action] = 'apply'
                    Log.debug(debug_message)
                  end

                  # We always remove the complex object and if it's time
                  # we insert the string
                  GLOBAL_CONFIG[:data][tl][k]['member'].delete(m)
                  GLOBAL_CONFIG[:data][tl][k]['member'] << u['dn'] unless too_early
                else
                  Log.fatal(
                    'Encountered invalid type in member array',
                    object: k
                  )
                end
              end
            end
          end
        end

        module_function

        # Lists all the groups
        # @since 0.1.0
        def list_all_groups
          newobj = {}
          GLOBAL_CONFIG[:data].each do |_k, v|
            newobj.merge!(v)
          end
          newobj
        end

        # List all organizational groups defined in local configuration.
        # @since 0.1.0
        def list_org_groups
          GLOBAL_CONFIG[:data][:organizational]
        end

        # List all organizational groups defined in local configuration.
        # @since 0.1.0
        def list_perm_groups
          GLOBAL_CONFIG[:data][:permissions]
        end

        # List all funcitonal groups defined in local configuration
        # @since 1.0.0
        def list_func_groups
          GLOBAL_CONFIG[:data][:functional]
        end

        # List all location groups defined in local configuration.
        # @since 0.1.0
        def list_locations
          GLOBAL_CONFIG[:data][:locations]
        end

        # List all users defined in local configuration.
        # @since 0.1.0
        def list_users
          users = []
          list_all_groups.each do |_k, v|
            next if v.nil?
            next unless v.key?('member')
            next if v['member'].nil?

            users += v['member']
          end
          users = users.uniq.sort - list_all_groups.keys
        end
      end
    end
  end
end
