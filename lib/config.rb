# The global config instance.
# @since 0.1.0
module AdGear
  module Infrastructure
    module GroupManager
      module Config
        require('yaml')
        require_relative('logging')

        include AdGear::Infrastructure::GroupManager::Logging

        # The global config instance
        # rubocop:disable Style/MutableConstant
        GLOBAL_CONFIG = {
          data: {
            locations: {},
            organizational: {},
            functional: {},
            permissions: {}
          }
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

          # This block sanitizes the schema of incoming configuration to ignore any unknown keys
          # It's the _"next best thing"_ short of casting the individual items onto a schema. ;_;
          GLOBAL_CONFIG[:data].each do |type, _|
            Log.debug("type" => type)
            GLOBAL_CONFIG[:data][type].each do |group, _|
              Log.debug("group" => group)
              Log.debug(GLOBAL_CONFIG[:data][type][group])
              unknown_keys = GLOBAL_CONFIG[:data][type][group].keys.reject { |k| [ 'description', 'member' ].include?(k) }

              Log.debug(unknown_keys)
              unknown_keys.each do |k|
                GLOBAL_CONFIG[:data][type][group].delete(k)
                Log.debug("deleted #{type}.#{group}.#{k}")
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
