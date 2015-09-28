require 'puppet/parameter/boolean'
require File.join File.dirname(__FILE__), '../pacemaker/type'

module Puppet
  newtype(:pcmk_order) do
    desc %q(Type for manipulating Corosync/Pacemkaer ordering entries.  Order
      entries are another type of constraint that can be put on sets of
      primitives but unlike colocation, order does matter.  These designate
      the order at which you need specific primitives to come into a desired
      state before starting up a related primitive.

      More information can be found at the following link:

      * http://www.clusterlabs.org/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_controlling_resource_start_stop_ordering.html)

    ensurable
    include Pacemaker::Type

    newparam(:name) do
      desc %q(Name identifier of this ordering entry.  This value needs to be unique
        across the entire Corosync/Pacemaker configuration since it doesn\'t have
        the concept of name spaces per type.)
      isnamevar
    end

    newparam(:debug, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc %q(Don't actually make changes)
      defaultto false
    end

    newproperty(:first) do
      desc %q(First Corosync primitive.)
    end

    newproperty(:second) do
      desc %q(Second Corosync primitive.)
    end

    newproperty(:score) do
      desc %q(The priority of the this ordered grouping.  Primitives can be a part
        of multiple order groups and so there is a way to control which
        primitives get priority when forcing the order of state changes on
        other primitives.  This value can be an integer but is often defined
        as the string INFINITY.)

      validate do |value|
        break if %w(inf INFINITY -inf -INFINITY).include? value
        break if value.to_i.to_s == value
        fail 'Score parameter is invalid, should be +/- INFINITY(or inf) or Integer'
      end

      munge do |value|
        value.gsub 'inf', 'INFINITY'
      end

      defaultto 'INFINITY'
    end

    autorequire(:service) do
      ['corosync']
    end

    autorequire(:pcmk_resource) do
      resources = []
<<<<<<< HEAD
      resources << primitive_base_name(self[:first]) if self[:first]
      resources << primitive_base_name(self[:second]) if self[:second]
=======
      resources << primitive_base_name(self[:primitive]) if self[:primitive]
>>>>>>> 96d4fc04c8f0514d6113641cfca826ccda8d3aa1
      debug "Autorequire pcmk_resources: #{resources.join ', '}" if resources.any?
      resources
    end

  end
end
