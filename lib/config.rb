# The global config instance.
# @since 0.1.0
module AdGear::Infrastructure::GroupManager::Config
  require('yaml')
  require('deep_fetch')
  require_relative('logging')

  include AdGear::Infrastructure::GroupManager::Logging

  # The global config instance
  GLOBAL_CONFIG = {
    data: {
      locations: {},
      organizational: {},
      permissions: {}
    }
  }

  GLOBAL_CONFIG['user_dn'] = ENV['AG_USER_DN'] || nil
  GLOBAL_CONFIG['password'] = ENV['AG_PASSWORD'] || nil
  GLOBAL_CONFIG['ldap_host'] = ENV['AG_LDAP_HOST'] || nil
  GLOBAL_CONFIG['treebase'] = ENV['AG_TREEBASE'] || nil
  GLOBAL_CONFIG['local_state'] = ENV['AG_LOCAL_STATE'] || Dir.pwd

  GLOBAL_CONFIG.freeze

  config_files = Dir.glob(File.join(GLOBAL_CONFIG['local_state'], '**/*.yml'))

  config_files.each do |file|
    Log.debug("loading #{file}")
    parts = file.split('/').reject(&:empty?)
    target = parts[parts.length - 2]
    Log.debug("target: #{target}")
    data = YAML.safe_load(File.read(file)) || {}
    GLOBAL_CONFIG[:data][target.to_sym].merge!(data)
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

  def list_org_groups
    GLOBAL_CONFIG[:data][:organizational]
  end

  def list_perm_groups
    GLOBAL_CONFIG[:data][:permissions]
  end

  def list_locations
    GLOBAL_CONFIG[:data][:locations]
  end

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
