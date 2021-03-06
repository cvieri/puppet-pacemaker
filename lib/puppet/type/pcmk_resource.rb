require 'puppet/parameter/boolean'
require File.join File.dirname(__FILE__), '../pacemaker/type'

module Puppet
  newtype(:pcmk_resource) do
    desc %q(Type for manipulating Corosync/Pacemaker primitives.  Primitives
      are probably the most important building block when creating highly
      available clusters using Corosync and Pacemaker.  Each primitive defines
      an application, ip address, or similar to monitor and maintain.  These
      managed primitives are maintained using what is called a resource agent.
      These resource agents have a concept of class, type, and subsystem that
      provides the functionality.  Regretibly these pieces of vocabulary
      clash with those used in Puppet so to overcome the name clashing the
      property and parameter names have been qualified a bit for clarity.

      More information on primitive definitions can be found at the following
      link:

      * http://www.clusterlabs.org/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_adding_a_resource.html)

    ensurable
    include Pacemaker::Type

    newparam(:name) do
      desc %q(Name identifier of primitive.  This value needs to be unique
        across the entire Corosync/Pacemaker configuration since it doesn't have
        the concept of name spaces per type.)
      isnamevar
    end

    newparam(:debug, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc %q(Don't actually make changes)
      defaultto false
    end

    newproperty(:primitive_class) do
      desc %q(Corosync class of the primitive.  Examples of classes are lsb or ocf.
        Lsb funtions a lot like the init provider in Puppet for services, an init
        script is ran periodically on each host to identify status, or to start
        and stop a particular application.  Ocf of the other hand is a script with
        meta-data and stucture that is specific to Corosync and Pacemaker.)
      isrequired
    end

    newproperty(:primitive_type) do
      desc %q(Corosync primitive type.  Type generally matches to the specific
        'thing' your managing, i.e. ip address or vhost.  Though, they can be
        completely arbitarily named and manage any number of underlying
        applications or resources.)
      isrequired
    end

    newproperty(:primitive_provider) do
      desc %q(Corosync primitive provider.  All resource agents used in a primitve
        have something that provides them to the system, be it the Pacemaker or
        redhat plugins... they're not always obvious though so currently you're
        left to understand Corosync enough to figure it out.  Usually, if it isn't
        obvious it is because there is only one provider for the resource agent.

        To find the list of providers for a resource agent run the following
        from the command line has Corosync installed:

        * `crm configure ra providers <ra> <class>`)
      isrequired
    end

    # Our parameters and operations properties must be hashes.
    newproperty(:parameters) do
      desc %q(A hash of params for the primitive.  Parameters in a primitive are
        used by the underlying resource agent, each class using them slightly
        differently.  In ocf scripts they are exported and pulled into the
        script as variables to be used.  Since the list of these parameters
        are completely arbitrary and validity not enforced we simply defer
        defining a model and just accept a hash.)

      validate do |value|
        unless value.is_a? Hash
          fail 'Parameters property must be a hash'
        end
      end

      def is_to_s(is)
        resource.inspect_to_s is
      end

      def should_to_s(should)
        resource.inspect_to_s should
      end

      def insync?(is)
        resource.insync_debug is, should, 'parameters'
        super
      end

      munge do |value|
        resource.stringify_data value
      end
    end

    newproperty(:operations, :array_matching => :all) do
      desc %q(A hash of operations for the primitive.  Operations defined in a
        primitive are little more predictable as they are commonly things like
        monitor or start and their values are in seconds.  Since each resource
        agent can define its own set of operations we are going to defer again
        and just accept a hash. There maybe room to model this one but it
        would require a review of all resource agents to see if each operation
        is valid.)

      validate do |value|
        unless value.is_a? Hash
          fail 'Operations property must be a hash.'
        end
      end

      munge do |value|
        resource.stringify_data value
      end

      def should=(value)
        super
        @should = resource.munge_operations @should
      end

      def is_to_s(is)
        resource.inspect_to_s is
      end

      def should_to_s(should)
        resource.inspect_to_s should
      end

      def insync?(is)
        resource.insync_debug is, should, 'operations'
        resource.compare_operations is, should
      end
    end

    newproperty(:metadata) do
      desc %q(A hash of metadata for the primitive.  A primitive can have a set of
        metadata that doesn't affect the underlying Corosync type/provider but
        affect that concept of a resource.  This metadata is similar to Puppet's
        resources resource and some meta-parameters, they change resource
        behavior but have no affect of the data that is synced or manipulated.)

      validate do |value|
        unless value.is_a? Hash
          fail 'Metadata property must be a hash'
        end
      end

      munge do |value|
        resource.stringify_data value
        value = resource.stringify_data value
        resource.munge_meta_attributes value
      end

      def is_to_s(is)
        resource.inspect_to_s is
      end

      def should_to_s(should)
        resource.inspect_to_s should
      end

      def insync?(is)
        resource.insync_debug is, should, 'metadata'
        resource.compare_meta_attributes is, should
      end
    end

    newproperty(:complex_metadata) do
      desc %q(A hash of metadata for the multistate state)

      validate do |value|
        unless value.is_a? Hash
          fail 'Complex_metadata property must be a hash'
        end
      end

      munge do |value|
        resource.stringify_data value
        value = resource.stringify_data value
        resource.munge_meta_attributes value
      end

      def is_to_s(is)
        resource.inspect_to_s is
      end

      def should_to_s(should)
        resource.inspect_to_s should
      end

      def insync?(is)
        resource.insync_debug is, should, 'complex_metadata'
        resource.compare_meta_attributes is, should
      end
    end

    newproperty(:complex_type) do
      desc %q(Designates if the primitive is capable of being managed in a multistate
        state.  This will create a new ms or clone resource in your Corosync config and add
        this primitive to it.  Concequently Corosync will be helpful and update all
        your colocation and order resources too but Puppet won't. Hash contains
        two key-value pairs: type (master, clone) and its name (${type}_{$primitive_name})
        by default')

      newvalues 'clone', 'master'
    end

    autorequire(:service) do
      ['corosync']
    end

  end
end
