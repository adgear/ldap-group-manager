# frozen_string_literal: true

# The global utils container. Used for storing common stuff.
# @since 0.1.0
module AdGear::Infrastructure::GroupManager::Utils
  require_relative('./config')
  require_relative('./logging')

  include AdGear::Infrastructure::GroupManager::Config
  include AdGear::Infrastructure::GroupManager::Logging

  module_function

  # A helper method that allows to log an error and exit.
  # @param [Array] args passes all arguments, as is, to Ougai.
  # @return [nil] no return.
  # @since 0.1.0
  def stringify_all_keys(hash)
    stringified_hash = {}
    hash.each do |k, v|
      stringified_hash[k.to_s] = v.is_a?(Hash) ? stringify_all_keys(v) : v
    end
    stringified_hash
  end

  def symbolify_all_keys(hash)
    Log.debug(msg: 'symbolifiying', data: hash)
    symbolified = {}
    hash.keys.each do |k|
      newkey = %w[member description].include?(k) ? k.to_sym : k
      symbolified[newkey] = hash[k].is_a?(Hash) ? symbolify_all_keys(hash[k]) : hash[k]
    end
    symbolified
  end

  def diff_op_exist?(ops, type, target)
    ops.select { |op| op[0] == type && op[1] == target }.any?
  end

  def duplicate?(ops, item)
    opposite = case item[0]
               when '-'
                 '+'
               when '+'
                 '-'
               end
    ops.select { |op| op[0] == opposite && op[1] == item[1] && op[2] == item[2] }.any?
  end

  def find_ou(dn)
    if GLOBAL_CONFIG[:data][:organizational].key?(dn)
      'OU=Organizational, OU=Keycloak Groups'
    elsif GLOBAL_CONFIG[:data][:permissions].key?(dn)
      'OU=Permission, OU=Keycloak Groups'
    elsif GLOBAL_CONFIG[:data][:locations].key?(dn)
      'OU=Location, OU=Keycloak Groups'
    else
      'OU=Keycloak Users'
    end
  end

  def sort_member(all_groups)
    ordered_groups = {}
    all_groups.keys.sort.each do |group|
      ordered_groups[group] = {}
      all_groups[group].sort.map { |k, v| ordered_groups[group][k] = v }
      unless !all_groups[group].key?(:member) || all_groups[group][:member].nil?
        ordered_groups[group].delete(:member)
        ordered_groups[group][:member] = all_groups[group][:member].sort
      end
    end
    ordered_groups
  end

  def create_ops_list(local_groups, remote_groups)
    operations = {
      create: [],
      modify: [],
      delete: []
    }

    local_groups.each do |gr, vals|
      # if remote group exists, diff each attribute
      if remote_groups.key?(gr)
        vals.keys.each do |key|
          message = {
            msg: "diffing local and remote instances of #{gr}",
            cn: gr,
            attrib: key,
            local: local_groups[gr][key],
            remote: remote_groups.dig(gr, key),
            require_change: compare_attributes(local_groups[gr][key], remote_groups.dig(gr, key))
          }
          Log.debug(message) if message[:require_change]
          if compare_attributes(local_groups[gr][key], remote_groups.dig(gr, key))
            operations[:modify] << { cn: gr, attrib: key, value: local_groups[gr][key] }
          end
        end
      else
        # if remote group doesn't exist create key, then modify
        operations[:create] << gr
        vals.keys.each do |key|
          operations[:modify] << { cn: gr, attrib: key, value: local_groups[gr][key] }
        end
      end
    end

    # delete remote groups that aren't locally described
    (remote_groups.keys - local_groups.keys).each { |gr| operations[:delete] << gr }

    # return stuff to do
    operations
  end

  def compare_attributes(local, remote)
    (local == [] ? nil : local) != remote
  end
end