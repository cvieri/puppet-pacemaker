module Puppet::Type::Pacemaker

  # output IS and SHOULD values for debugging
  def insync_debug(is, should, tag = nil)
    debug "insync?: #{tag}" if tag
    debug "IS: #{is.inspect} #{is.class}"
    debug "SH: #{should.inspect} #{should.class}"
  end

  # convert data structure to strings
  def stringify_data(data)
    if data.is_a? Hash
      new_data = {}
      data.each do |key, value|
        new_data.store stringify_data(key), stringify_data(value)
      end
      data.clear
      data.merge! new_data
    elsif data.is_a? Array
      data.map! do |element|
        stringify_data element
      end
    else
      data.to_s
    end
  end

  # modify provided operations data
  def munge_operations(operations_from)
    operations_from = [operations_from] unless operations_from.is_a? Array
    operations_to = []
    operations_from.each do |operation|
      # operations were provided as an array
      # save array entry
      if operation['name']
        operations_to << operation
        next
      end
      # operations were provided as a hash
      # generate array entry
      operation.each do |operation_name, operation_data|
        next unless operation_data.is_a? Hash
        operation_structure = {}
        if operation_name.include? ':'
          operation_name_array = operation_name.split(':')
          operation_name = operation_name_array[0]
          if not operation_data['role'] and operation_name_array[1]
            operation_data['role'] = operation_name_array[1]
          end
        end

        operation_structure['name'] = operation_name
        operation_structure.merge! operation_data
        operations_to << operation_structure if operation_structure.any?
      end
    end

    # set default interval and normalize role
    # set intervals to zero for non-monitor operations
    operations_to.each do |operation|
      operation['interval'] = '0' unless operation['interval']
      operation['interval'] = '0' if operation['name'] != 'monitor'
      operation['role'].capitalize! if operation['role']
    end

    # sort operations array by "id"
    operations_to.sort_by do |operation|
      sort_order = [operation['name'], operation['interval'], operation['role']]
      sort_order.reject! { |c| c.nil? }
      sort_order.join '-'
    end
  end

  # compare meta_attribute hashes
  # exclude status_metadata from comparison
  # @param is [Hash]
  # @param should [Hash]
  # @return [true,false]
  def compare_meta_attributes(is, should)
    return unless is.is_a? Hash and should.is_a? Hash
    status_metadata = %w(target-role is-managed)
    is_without_state = is.reject do |k, v|
      status_metadata.include? k.to_s
    end
    should_without_state = should.reject do |k, v|
      status_metadata.include? k.to_s
    end
    result = is_without_state == should_without_state
    debug "compare_meta_attributes: #{result}"
    result
  end

  # generate operation id for sorting
  # @param operation [Hash]
  # @return [String]
  def operation_id(operation)
    id_components = [operation['name'], operation['role'], operation['interval']]
    id_components.reject! { |v| v.nil? }
    id_components.join '-'
  end

  # sort operations array before insync?
  # to make different order and same data arrays equal
  # @param is [Array]
  # @param should [Array]
  # @return [true,false]
  def compare_operations(is, should)
    if is.is_a? Array and should.is_a? Array
      is = is.sort_by { |operation| operation_id operation }
      should = should.sort_by  { |operation| operation_id operation }
    end
    result = is == should
    debug "compare_operations: #{result}"
    result
  end

  # remove status related meta attributes
  # @param attributes_from [Hash]
  # @return [Hash]
  def munge_meta_attributes(attributes_from)
    attributes_to = {}
    attributes_from.each do |name, parameters|
      next if %w(target-role is-managed).include? name
      attributes_to.store name, parameters
    end
    attributes_to
  end

  # normalize a single location rule
  def munge_rule(rule, rule_number, title)
    rule['id'] = "#{title}-rule-#{rule_number}" unless rule['id']
    rule['boolean-op'] = 'or' unless rule['boolean-op']
    rule['score'].gsub! 'inf', 'INFINITY' if rule['score']
    if rule['expressions']
      unless rule['expressions'].is_a? Array
        expressions_array = []
        expressions_array << rule['expressions']
        rule['expressions'] = expressions_array
      end
      expression_number = 0
      rule['expressions'].each do |expression|
        unless expression['id']
          expression['id'] = "#{title}-rule-#{rule_number}-expression-#{expression_number}"
        end
        expression_number += 1
      end
    end
    rule
  end

end
