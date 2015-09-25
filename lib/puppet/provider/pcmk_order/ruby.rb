require File.join File.dirname(__FILE__), '../pacemaker/provider'

Puppet::Type.type(:pcmk_order).provide(:ruby, :parent => Puppet::Provider::Pacemaker) do
  desc 'Specific provider for a rather specific type since I currently have no plan to
        abstract corosync/pacemaker vs. keepalived. This provider will check the state
        of current primitive start orders on the system; add, delete, or adjust various
        aspects.'

  commands :cibadmin => 'cibadmin'
  commands :crm_attribute => 'crm_attribute'
  commands :crm_node => 'crm_node'
  commands :crm_resource => 'crm_resource'
  commands :crm_attribute => 'crm_attribute'

  #TODO fail if there is no primitive

  attr_accessor :property_hash
  attr_accessor :resource

  def self.instances
    debug 'Call: self.instances'
    proxy_instance = self.new
    instances = []
    proxy_instance.constraint_orders.map do |title, data|
      parameters = {}
      debug "Prefetch constraint_order: #{title}"
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

  # retrieve data from library to the target_structure
  # @params data [Hash] extracted order data
  # will extract the current order data unless a value is provided
  # @param target_structure [Hash] copy data to this structure
  # defaults to the property_hash of this provider
  def retrieve_data(data=nil, target_structure = property_hash)
    data = constraint_orders.fetch resource[:name], {} unless data
    target_structure[:name] = data['id'] if data['id']
    target_structure[:ensure] = :present
    target_structure[:first] = data['first'] if data['first']
    target_structure[:second] = data['then'] if data['then']
    target_structure[:score] = data['score'] if data['score']
  end

  def exists?
    debug "Call: exists? on '#{resource}'"
    out = constraint_order_exists? resource[:name]
    retrieve_data
    debug "Return: #{out}"
    out
  end

  # check if the order ensure is set to present
  # @return [TrueClass,FalseClass]
  def present?
    property_hash[:ensure] == :present
  end

  # Create just adds our resource to the property_hash and flush will take care
  # of actually doing the work.
  def create
    debug "Call: create on '#{resource}'"
    self.property_hash = {
        :name => resource[:name],
        :ensure => :absent,
        :first => resource[:first],
        :second => resource[:second],
        :score => resource[:score],
    }
  end

  # Unlike create we actually immediately delete the item.
  def destroy
    debug "Call: destroy on '#{resource}'"
    constraint_order_remove resource[:name]
    property_hash.clear
    cluster_debug_report "#{resource} destroy"
  end

  # Getters that obtains the first and second primitives and score in our
  # ordering definintion that have been populated by prefetch or instances
  # (depends on if your using puppet resource or not).
  def first
    property_hash[:first]
  end

  def second
    property_hash[:second]
  end

  def score
    property_hash[:score]
  end

  # Our setters for the first and second primitives and score.  Setters are
  # used when the resource already exists so we just update the current value
  # in the property hash and doing this marks it to be flushed.
  def first=(should)
    property_hash[:first] = should
  end

  def second=(should)
    property_hash[:second] = should
  end

  def score=(should)
    property_hash[:score] = should
  end

  # Flush is triggered on anything that has been detected as being
  # modified in the property_hash.  It generates a temporary file with
  # the updates that need to be made.  The temporary file is then used
  # as stdin for the crm command.
  def flush
    debug "Call: flush on '#{resource}'"
    return unless property_hash and property_hash.any?

    order_structure = {}
    order_structure['id'] = property_hash[:name]
    order_structure['score'] = property_hash[:score]
    order_structure['first'] = property_hash[:first]
    order_structure['then'] = property_hash[:second]

    unless order_structure['id'] and order_structure['score'] and
        order_structure['first'] and order_structure['then']
      fail "Data does not contain all the required fields #{order_structure.inspect} at '#{resource}'"
    end

    order_patch = xml_document
    order_element = xml_rsc_order order_structure
    fail "Could not create XML patch for '#{resource}'" unless order_element
    order_patch.add_element order_element
    if present?
      cibadmin_modify xml_pretty_format(order_patch.root), 'constraints'
    else
      cibadmin_create xml_pretty_format(order_patch.root), 'constraints'
    end
    cluster_debug_report "#{resource} flush"
  end
end
