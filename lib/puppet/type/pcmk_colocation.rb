require 'puppet/parameter/boolean'
require File.join File.dirname(__FILE__), '../pacemaker/type'

module Puppet
  newtype(:pcmk_colocation) do
    desc %q(Type for manipulating corosync/pacemaker colocation.  Colocation
      is the grouping together of a set of primitives so that they travel
      together when one of them fails.  For instance, if a web server vhost
      is colocated with a specific ip address and the web server software
      crashes, the ip address with migrate to the new host with the vhost.

      More information on Corosync/Pacemaker colocation can be found here:

      * http://www.clusterlabs.org/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_ensuring_resources_run_on_the_same_host.html)

    ensurable
    include Pacemaker::Type

    newparam(:name) do
      desc %q(Identifier of the colocation entry. This value needs to be unique
        across the entire Corosync/Pacemaker configuration since it doesn't have
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
      desc %q(The priority of this colocation.  Primitives can be a part of
        multiple colocation groups and so there is a way to control which
        primitives get priority when forcing the move of other primitives.
        This value can be an integer but is often defined as the string
        INFINITY.)

      defaultto 'INFINITY'

      validate do |value|
        break if %w(inf INFINITY -inf -INFINITY).include? value
        break if value.to_i.to_s == value
        fail 'Score parameter is invalid, should be +/- INFINITY(or inf) or Integer'
      end

      munge do |value|
        value.gsub 'inf', 'INFINITY'
      end

      isrequired
    end

    autorequire(:service) do
      ['corosync']
    end

    autorequire(:pcmk_resource) do
      resources = []
      resources << primitive_base_name(self[:first]) if self[:first]
      resources << primitive_base_name(self[:second]) if self[:second]
      debug "Autorequire pcmk_resources: #{resources.join ', '}" if resources.any?
      resources
    end

  end
end
