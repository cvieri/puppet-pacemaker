require File.join File.dirname(__FILE__), '../../pacemaker/provider'

Puppet::Type.type(:pcmk_resource).provide(:ruby, :parent => Puppet::Provider::Pacemaker) do
  desc 'Specific provider for a rather specific type since I currently have no
        plan to abstract corosync/pacemaker vs. keepalived.  Primitives in
        Corosync are the thing we desire to monitor; websites, ipaddresses,
        databases, etc, etc.  Here we manage the creation and deletion of
        these primitives.  We will accept a hash for what Corosync calls
        operations and parameters.  A hash is used instead of constucting a
        better model since these values can be almost anything.'

  commands :cibadmin => 'cibadmin'
  commands :crm_attribute => 'crm_attribute'
  commands :crm_node => 'crm_node'
  commands :crm_resource => 'crm_resource'
  commands :crm_attribute => 'crm_attribute'

  defaultfor :kernel => 'Linux'

  attr_accessor :property_hash
  attr_accessor :resource

  def self.instances
    debug 'Call: self.instances'
    proxy_instance = self.new
    instances = []
    proxy_instance.primitives.map do |title, data|
      parameters = {}
      debug "Prefetch resource: #{title}"
      proxy_instance.retrieve_data data, parameters
      instance = self.new(parameters)
      instance.cib = proxy_instance.cib
      instances << instance
    end
    instances
  end

  def self.prefetch(catalog_instances)
    debug 'Call: self.prefetch'
    return unless pacemaker_options[:prefetch]
    discovered_instances = instances
    discovered_instances.each do |instance|
      next unless catalog_instances.key? instance.name
      catalog_instances[instance.name].provider = instance
    end
  end

  # import attributes structure from library representation to puppet
  # @param attributes [Hash,Array,NilClass] hash or array of attributes from library
  # @return [Hash] attributes (name => value)
  def import_attributes(attributes)
    return unless attributes.respond_to? :each
    hash = {}
    attributes.each do |attribute|
      if attribute.is_a? Array and attribute.length == 2
        attribute = attribute[1]
      end
      next unless attribute['name'] and attribute['value']
      hash.store attribute['name'], attribute['value']
    end
    hash
  end

  # export puppet representation of attributes to the library one
  # @param hash [Hash] attributes (name => value)
  # @param attributes_id_tag [String] attributes name for id naming
  # @return [Hash,NilClass]
  def export_attributes(hash, attributes_id_tag)
    return unless hash.is_a? Hash
    attributes = {}
    hash.each do |attribute_name, attribute_value|
      id_components = [resource[:name], attributes_id_tag, attribute_name]
      id_components.reject! { |v| v.nil? }
      attribute_structure = {}
      attribute_structure['id'] = id_components.join '-'
      attribute_structure['name'] = attribute_name
      attribute_structure['value'] = attribute_value
      attributes.store attribute_name, attribute_structure
    end
    attributes
  end

  # retrieve data from library to the target_structure
  # @param data [Hash] extracted primitive data
  # will extract the current primitive data unless a value is provided
  # @param target_structure [Hash] copy data to this structure
  # defaults to the property_hash of this provider
  def retrieve_data(data=nil, target_structure = property_hash)
    debug 'Call: retrieve_data'
    data = primitives.fetch resource[:name], {} unless data
    target_structure[:ensure] = :present
    copy_value data, 'id', target_structure, :name
    copy_value data, 'class', target_structure, :primitive_class
    copy_value data, 'provider', target_structure, :primitive_provider
    copy_value data, 'type', target_structure, :primitive_type

    if data['complex']
      target_structure[:complex_type] = data['complex']['type'].to_sym if data['complex']['type']
      complex_metadata = import_attributes data['complex']['meta_attributes']
      target_structure[:complex_metadata] = complex_metadata if complex_metadata
    end

    if data['instance_attributes']
      parameters_data = import_attributes data['instance_attributes']
      if parameters_data and parameters_data.is_a? Hash
        target_structure[:parameters] = parameters_data if parameters_data
      end
    end

    if data['meta_attributes']
      metadata_data = import_attributes data['meta_attributes']
      if metadata_data and metadata_data.is_a? Hash
        target_structure[:metadata] = metadata_data
      end
    end

    if data['operations']
      operations_data = []
      sort_data(data['operations']).each do |operation|
        operation.delete 'id'
        operations_data << operation
      end
      target_structure[:operations] = operations_data
    end

  end

  def exists?
    debug 'Call: exists?'
    out = primitive_exists? resource[:name]
    retrieve_data
    debug "Return: #{out}"
    out
  end

  # check if the location ensure is set to present
  # @return [TrueClass,FalseClass]
  def present?
    property_hash[:ensure] == :present
  end

  def complex_change?
    primitive_complex_type(resource[:name]) != property_hash[:complex_type]
  end

  # Create just adds our resource to the property_hash and flush will take care
  # of actually doing the work.
  def create
    debug 'Call: create'
    self.property_hash = {
        :ensure => :absent,
    }

    parameters = [
        :name,
        :primitive_class,
        :primitive_provider,
        :primitive_type,
        :parameters,
        :operations,
        :metadata,
        :complex_type,
        :complex_metadata,
    ]

    parameters.each do |key|
      copy_value resource, key, property_hash
    end
  end

  # use cibadmin to remove the XML section describing this primitive
  def remove_primitive
    return unless primitive_exists? resource[:name]
    primitive_tag = 'primitive'
    primitive_tag = primitive_complex_type resource[:name] if primitive_is_complex? resource[:name]
    cibadmin_delete "<#{primitive_tag} id='#{primitive_full_name resource[:name]}'/>", 'resources'
  end

  # Unlike create we actually immediately delete the item.  Corosync forces us
  # to "stop" the primitive before we are able to remove it.
  def destroy
    debug 'Call: destroy'
    remove_primitive
    property_hash.clear
    cluster_debug_report "#{resource} destroy"
  end

  # Getters that obtains the parameters and operations defined in our primitive
  # that have been populated by prefetch or instances (depends on if your using
  # puppet resource or not).
  def parameters
    property_hash[:parameters]
  end

  def operations
    property_hash[:operations]
  end

  def metadata
    property_hash[:metadata]
  end

  def complex_metadata
    property_hash[:complex_metadata]
  end

  def complex_type
    property_hash[:complex_type]
  end

  def primitive_class
    property_hash[:primitive_class]
  end

  def primitive_provider
    property_hash[:primitive_provider]
  end

  def primitive_type
    property_hash[:primitive_type]
  end

  def full_name
    if complex_type
      "#{complex_type}_#{resource[:name]}"
    else
      resource[:name]
    end
  end

  # Our setters for parameters and operations.  Setters are used when the
  # resource already exists so we just update the current value in the
  # property_hash and doing this marks it to be flushed.
  def parameters=(should)
    property_hash[:parameters] = should
  end

  def operations=(should)
    property_hash[:operations] = should
  end

  def metadata=(should)
    property_hash[:metadata] = should
  end

  def complex_metadata=(should)
    property_hash[:complex_metadata] = should
  end

  def complex_type=(should)
    property_hash[:complex_type] = should
  end

  def primitive_class=(should)
    property_hash[:primitive_class] = should
  end

  def primitive_provider=(should)
    property_hash[:primitive_provider] = should
  end

  def primitive_type=(should)
    property_hash[:primitive_type] = should
  end

  # Flush is triggered on anything that has been detected as being
  # modified in the property_hash.  It generates a temporary file with
  # the updates that need to be made.  The temporary file is then used
  # as stdin for the crm command.  We have to do a bit of munging of our
  # operations and parameters hash to eventually flatten them into a string
  # that can be used by the crm command.
  def flush
    debug 'Call: flush'
    return unless property_hash and property_hash.any?

    if property_hash[:complex_metadata] and not property_hash[:complex_type]
      fail 'You should not use ms_metadata if your resource is not clone or master!' if self[:complex_metadata].any?
    end

    unless property_hash[:primitive_type] and property_hash[:primitive_provider] and property_hash[:primitive_class]
      fail 'Primitive class, type and provider should present!'
    end

    if complex_change?
      remove_primitive
      property_hash[:ensure] = :absent
    end

    # basic primitive structure
    primitive_structure = {}
    copy_value property_hash, :name, primitive_structure, 'id'
    copy_value property_hash, :name, primitive_structure, 'name'
    copy_value property_hash, :primitive_class, primitive_structure, 'class'
    copy_value property_hash, :primitive_provider, primitive_structure, 'provider'
    copy_value property_hash, :primitive_type, primitive_structure, 'type'

    # complex structure
    if complex_type
      complex_structure = {}
      complex_structure['type'] = property_hash[:complex_type].to_s
      complex_structure['id'] = full_name

      # complex meta_attributes structure
      if property_hash[:complex_metadata] and property_hash[:complex_metadata].any?
        meta_attributes_structure = export_attributes property_hash[:complex_metadata], 'meta_attributes'
        complex_structure['meta_attributes'] = meta_attributes_structure if meta_attributes_structure
      end

      primitive_structure['name'] = complex_structure['id']
      primitive_structure['complex'] = complex_structure
    end

    # operations structure
    if property_hash[:operations] and property_hash[:operations].any?
      primitive_structure['operations'] = {}
      property_hash[:operations].each do |operation|
        if operation.is_a? Array and operation.length == 2
          # operations were provided and Hash { name => { parameters } }, convert it
          name = operation[0]
          operation = operation[1]
          operation['name'] = name unless operation['name']
        end
        unless operation['id']
          # there is no id provided, generate it
          id_components = [property_hash[:name], operation['name'], operation['interval']]
          id_components.reject! { |v| v.nil? }
          operation['id'] = id_components.join '-'
        end
        primitive_structure['operations'].store operation['id'], operation
      end
    end

    # instance_attributes structure
    if property_hash[:parameters] and property_hash[:parameters].any?
      instance_attributes_structure = export_attributes property_hash[:parameters], 'instance_attributes'
      primitive_structure['instance_attributes'] = instance_attributes_structure if instance_attributes_structure
    end

    # meta_attributes structure
    if property_hash[:metadata] and property_hash[:metadata].any?
      meta_attributes_structure = export_attributes property_hash[:metadata], 'meta_attributes'
      primitive_structure['meta_attributes'] = meta_attributes_structure
    end

    # create and apply XML patch
    primitive_patch = xml_document
    primitive_element = xml_primitive primitive_structure
    fail "Could not create XML patch for '#{resource}'" unless primitive_element
    primitive_patch.add_element primitive_element
    if present?
      cibadmin_modify xml_pretty_format(primitive_patch.root), 'resources'
    else
      cibadmin_create xml_pretty_format(primitive_patch.root), 'resources'
    end
    cluster_debug_report "#{resource} flush"
  end

end
