require File.join File.dirname(__FILE__), '../pacemaker/provider'

Puppet::Type.type(:pcmk_colocation).provide(:ruby, :parent => Puppet::Provider::Pacemaker) do
  desc %q(Specific provider for a rather specific type since I currently have no plan to
        abstract corosync/pacemaker vs. keepalived.  This provider will check the state
        of current primitive colocations on the system; add, delete, or adjust various
        aspects.)

  commands :cibadmin => 'cibadmin'
  commands :crm_attribute => 'crm_attribute'
  commands :crm_node => 'crm_node'
  commands :crm_resource => 'crm_resource'
  commands :crm_attribute => 'crm_attribute'

  #TODO instances
  #TODO prefetch
  #TODO fail if there is no primitive

  attr_accessor :property_hash
  attr_accessor :resource

  def self.instances
    debug 'Call: self.instances'
    proxy_instance = self.new
    instances = []
    proxy_instance.constraint_colocations.map do |title, data|
      parameters = {}
      debug "Prefetch constraint_colocation: #{title}"
      proxy_instance.retrieve_data data, parameters
      instances << self.new(parameters)
    end
    instances
  end

  def self.prefetch(catalog_instances)
    debug 'Call: self.prefetch'
    discovered_instances = instances
    discovered_instances.each do |instance|
      next unless catalog_instances.key? instance.name
      catalog_instances[instance.name].provider = instance
    end
  end

  # retrieve data from library to the target_structure
  # @params data [Hash] extracted colocation data
  # will extract the current colocation data unless a value is provided
  # @param target_structure [Hash] copy data to this structure
  # defaults to the property_hash of this provider
  def retrieve_data(data=nil, target_structure = property_hash)
    data = constraint_colocations.fetch resource[:name], {} unless data
    target_structure[:name ] = data['id'] if data['id']
    target_structure[:ensure] = :present
    target_structure[:first] = data['with-rsc'] if data['with-rsc']
    target_structure[:second] = data['rsc'] if data['rsc']
    target_structure[:score] = data['score'] if data['score']
  end

  def exists?
    debug "Call: exists? on '#{resource}'"
    if retrieved?
      out = present?
    else
      out = constraint_colocation_exists? resource[:name]
      retrieve_data
    end
    debug "Return: #{out}"
    out
  end

  # check if the colocation ensure is set to present
  # @return [TrueClass,FalseClass]
  def present?
    property_hash[:ensure] == :present
  end

  # check if the colocation data have been either prefetched or retrieved
  # @return [TrueClass,FalseClass]
  def retrieved?
    property_hash.key? :ensure and property_hash.key? :name
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
    constraint_colocation_remove resource[:name]
    property_hash.clear
    cluster_debug_report "#{resource} destroy"
  end


  # Getter that obtains the our score that should have been populated by
  # prefetch or instances (depends on if your using puppet resource or not).
  def score
    property_hash[:score]
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

    colocation_structure = {}
    colocation_structure['id'] = property_hash[:name]
    colocation_structure['score'] = property_hash[:score]
    colocation_structure['rsc'] = property_hash[:second]
    colocation_structure['with-rsc'] = property_hash[:first]

    unless colocation_structure['id'] and colocation_structure['score'] and
        colocation_structure['rsc'] and colocation_structure['with-rsc']
      fail "Data does not contain all the required fields #{colocation_structure.inspect} at '#{resource}'"
    end

    colocation_patch = xml_document
    colocation_element = xml_rsc_colocation colocation_structure
    fail "Could not create XML patch for '#{resource}'" unless colocation_element
    colocation_patch.add_element colocation_element
    if present?
      cibadmin_modify xml_pretty_format(colocation_patch.root), 'constraints'
    else
      cibadmin_create xml_pretty_format(colocation_patch.root), 'constraints'
    end
    cluster_debug_report "#{resource} flush"
  end
end
