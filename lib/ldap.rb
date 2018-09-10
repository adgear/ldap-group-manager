# frozen_string_literal: true

# The global ldap instance. Uses the <code>net-ldap</code>.
# @since 0.1.0
module AdGear::Infrastructure::GroupManager::LDAP
  require('net-ldap')
  require_relative('./config')
  require_relative('./logging')
  require_relative('./utils')

  include AdGear::Infrastructure::GroupManager::Config
  include AdGear::Infrastructure::GroupManager::Logging
  include AdGear::Infrastructure::GroupManager::Utils

  Binder = Net::LDAP.new host: GLOBAL_CONFIG['ldap_host'],
                         port: 636,
                         encryption: {
                           method: :simple_tls,
                           tls_options: OpenSSL::SSL::SSLContext::DEFAULT_PARAMS
                         },
                         auth: {
                           method: :simple,
                           username: GLOBAL_CONFIG['user_dn'],
                           password: GLOBAL_CONFIG['password']
                         }

  module_function

  # Fetches a given item by CN.
  # @since 0.1.0
  def get_item(cn, location)
    treebase = GLOBAL_CONFIG['treebase']

    filter_string = ["distinguishedName=CN=#{cn}"]
    filter_string << location if location
    filter_string << treebase
    filter_string = filter_string.join(', ')

    filter = Net::LDAP::Filter.construct("(#{filter_string})")

    hash = {}
    Log.debug("Filter: #{filter}")

    Binder.search(base: treebase, filter: filter) do |entry|
      entry.each { |var| hash[var.to_s.delete('@')] = entry.public_send(var) }
      Log.debug(msg: 'Found this!', data: hash)
    end
    hash
  end

  # Verifies that a given user exists.
  # @since 0.1.0
  def user_exists?(dn)
    treebase = GLOBAL_CONFIG['treebase']

    filter_string = ["distinguishedName=CN=#{dn}"]
    filter_string << 'OU=Keycloak Users'
    filter_string << treebase

    filter = Net::LDAP::Filter.construct("(#{filter_string.join(', ')})")
    Binder.search(base: treebase, filter: filter).any?
  end

  # Modifies or creates an item.
  # This is shoddily written and modify and create should be split.
  # @since 0.1.0
  def set_item(action, dn, attrib = nil, val = nil)
    if action == :modify
      if attrib == :member && !val.nil?
        val.map! do |m|
          [
            "cn=#{m}",
            AdGear::Infrastructure::GroupManager::Utils.find_ou(m),
            AdGear::Infrastructure::GroupManager::GLOBAL_CONFIG['treebase']
          ].join(', ')
        end
        Binder.replace_attribute(dn, attrib, val)
      elsif val.nil?
        Binder.replace_attribute(dn, attrib, [])
      else
        Binder.replace_attribute(dn, attrib, val)
      end
      Log.debug(msg: 'Trying to set attribute', result: Binder.get_operation_result, dn: dn, key: attrib, value: val)
    elsif action == :create
      base_attributes = {
        samaccountname: dn.split(',').first.gsub(/cn=/i, ''),
        objectclass: %w[top group]
      }

      Binder.add(dn: dn, attributes: base_attributes)
      result = Binder.get_operation_result
      Log.debug(msg: 'Trying to add item', result: result, dn: dn)
    end
  end

  # Deletes an item. Kerplow!
  # @since 0.1.0
  def delete_item(dn)
    Binder.delete(dn: dn)
    result = Binder.get_operation_result
    Log.debug(msg: 'Trying to delete item', result: result, dn: dn)
  end

  # Lists organizational units in the remote instance.
  # @since 0.1.0
  def list_organizational_units
    treebase = GLOBAL_CONFIG['treebase']

    result = []

    filter = Net::LDAP::Filter.construct('(objectCategory=organizationalUnit)')
    Binder.search(base: treebase, filter: filter) do |entry|
      result.push(entry.dn) if entry.dn.match?(/OU=Keycloak Groups/)
    end
    result.empty? ? raise('No valid OUs found') : result
  end

  # Lists all groups in the remote instance.
  # @since 0.1.0
  def list_groups(treebase)
    filter = Net::LDAP::Filter.construct('(objectClass=group)')

    result = {}

    Log.debug(msg: 'base and filter', base: treebase, filter: filter.to_s)

    Binder.search(base: treebase, filter: filter) do |entry|
      obj = {}

      entry.each do |k, v|
        next unless [:member].include?(k)
        obj[k] = v.map { |p| extract_cn(p) }.sort
      end

      obj[:description] = entry.description if entry.respond_to?(:description)

      result[extract_cn(entry.dn)] = obj unless entry.dn.nil?
    end

    Binder.get_operation_result
    result.empty? ? raise('No results') : result
  end

  # Lists all organizational groups in the remote instance.
  # @since 0.1.0
  def list_org_groups
    list_groups(list_organizational_units.select { |g| g.match?(/^OU=Organizational/) }.first)
  end

  # Lists all permissions groups in the remote instance.
  # @since 0.1.0
  def list_perm_groups
    list_groups(list_organizational_units.select { |g| g.match?(/^OU=Permission/) }.first)
  end

  # Lists all location groups in the remote instance.
  # @since 0.1.0
  def list_locations
    list_groups(list_organizational_units.select { |g| g.match?(/^OU=Location/) }.first)
  end

  # Lists all groups groups in the remote instance.
  # @since 0.1.0
  def list_all_groups
    groups = {}
    groups.merge!(list_org_groups)
    groups.merge!(list_perm_groups)
    groups.merge!(list_locations)
    groups
  end

  # Extracts the CN out of a full DN.
  # @since 0.1.0
  def extract_cn(dn)
    dn.split(',').select { |p| p.match(/^CN=/) }.first.gsub('CN=', '')
  end
end
