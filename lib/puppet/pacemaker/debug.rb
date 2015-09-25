# debug related functions
# "cluster_debug_report" the main debug text generation function
# "safe_methods" are used to debug providers without making any actual changes to the system

module Pacemaker
  module Debug

    # check if debug is enabled either in the pacemaker options
    # or the resource has the 'debug' parameter and it's enabled
    # @return [TrueClass,FalseClass]
    def debug_enabled?
      return true if pacemaker_options[:debug_enabled]
      return true if @resource and @resource.parameters.keys.include?(:debug) and @resource[:debug]
      false
    end

    # Call a Puppet shell command method with wrappers
    # If debug is enabled, show what would be executed and don't actually
    # run the command. Used to debug commands that should modify the system
    # and don't return any data. Should never be use with commands that retrieve data.
    # If a command have failed, show command and the arguments and the raise the exception.
    # The actual commands methods should be created by the provider's "commands" helper.
    # @param cmd [Symbol, String] command name
    # @param *args [Array] command arguments
    # @return [String,NilClass]
    def safe_method(cmd, *args)
      cmd = cmd.to_sym unless cmd.is_a? Symbol
      if debug_enabled?
        debug ([cmd.to_s] + args).join ' '
        return
      end
      begin
        self.send cmd, *args
      rescue Exception => exception
        debug "Command execution have failed: #{cmd} #{args. join ' '}"
        raise exception
      end
    end

    # safe cibadmin command
    # @param args [Array] command arguments
    # @return [String,NilClass]
    def cibadmin_safe(*args)
      safe_method :cibadmin, *args
    end

    # safe crm_node command
    # @param args [Array] command arguments
    # @return [String,NilClass]
    def crm_node_safe(*args)
      safe_method :crm_node, *args
    end

    # safe cmapctl command
    # @param args [Array] command arguments
    # @return [String,NilClass]
    def cmapctl_safe(*args)
      safe_method :cmapctl, *args
    end

    # safe crm_resource command
    # @param args [Array] command arguments
    # @return [String,NilClass]
    def crm_resource_safe(*args)
      safe_method :crm_resource, *args
    end

    # safe crm_attribute command
    # @param args [Array] command arguments
    # @return [String,NilClass]
    def crm_attribute_safe(*args)
      safe_method :crm_attribute, *args
    end

################################################################################

    # generate report of primitive statuses by node
    # mostly for debugging
    # @return [Hash]
    def primitives_status_by_node
      report = {}
      return unless node_status.is_a? Hash
      node_status.each do |node_name, node_data|
        primitives_of_node = node_data['primitives']
        next unless primitives_of_node.is_a? Hash
        primitives_of_node.each do |primitive, primitive_data|
          primitive_status = primitive_data['status']
          report[primitive] = {} unless report[primitive].is_a? Hash
          report[primitive][node_name] = primitive_status
        end
      end
      report
    end

    # form a cluster status report for debugging
    # "(L)" - location constraint for this primitive is present on this node
    # "(F)" - the primitive is not running and have failed on this node
    # "(M)" - this primitive is not managed
    # @param tag [String] log comment tag to to trace calls
    # @return [String]
    def cluster_debug_report(tag = nil)
      return unless cib?
      report = "\n"
      report += 'Pacemaker debug block start'
      report += " at '#{tag}'" if tag
      report += "\n"
      primitives_status_by_node.each do |primitive, data|
        primitive_name = primitive
        primitive_name = primitives[primitive]['name'] if primitives[primitive]['name']
        primitive_type = 'Simple'
        primitive_type = 'Cloned' if primitive_is_clone? primitive
        primitive_type = 'Multistate' if primitive_is_multistate? primitive

        report += "-> #{primitive_type} primitive: '#{primitive_name}'"
        report += ' (M)' unless primitive_is_managed? primitive
        report += "\n"
        nodes = []
        data.keys.sort.each do |node_name|
          node_status_string = data.fetch node_name
          node_status_string = '?' unless node_status_string.is_a? String
          node_status_string = node_status_string.upcase
          node_block = "#{node_name}: #{node_status_string}"
          node_block += ' (F)' if primitive_has_failures? primitive, node_name and not primitive_is_running? primitive, node_name
          node_block += ' (L)' if service_location_exists? primitive_full_name(primitive), node_name
          nodes << node_block
        end
        report += '   ' + nodes.join(' | ') + "\n"
      end
      pacemaker_options[:debug_show_properties].each do |p|
        report += "* #{p}: #{cluster_property_value p}\n" if cluster_property_defined? p
      end
      report += 'Pacemaker debug block end'
      report += " at '#{tag}'" if tag
      report + "\n"
    end
  end
end
