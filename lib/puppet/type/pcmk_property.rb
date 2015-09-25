require 'puppet/parameter/boolean'
module Puppet
  newtype(:pcmk_property) do
    desc %q(Type for manipulating corosync/pacemaker configuration properties.
      Besides the configuration file that is managed by the module the contains
      all these related Corosync types and providers, there is a set of cluster
      properties that can be set and saved inside the CIB (A CIB being a set of
      configuration that is synced across the cluster, it can be exported as XML
      for processing and backup).  The type is pretty simple interface for
      setting key/value pairs or removing them completely.  Removing them will
      result in them taking on their default value.

      More information on cluster properties can be found here:

      * http://www.clusterlabs.org/doc/en-US/Pacemaker/1.1/html/Pacemaker_Explained/_cluster_options.html

      P.S Looked at generating a type dynamically from the cluster's property
      meta-data that would result in a single type with puppet type properties
      of every cluster property...may still do so in a later iteration.)

    ensurable

    newparam(:name) do
      desc %q(Name identifier of this property.  Simply the name of the cluster
        property.  Happily most of these are unique.)

      isnamevar
    end

    newparam(:debug, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc %q(Don't actually make changes)
      defaultto false
    end

    newproperty(:value) do
      desc %q(Value of the property.  It is expected that this will be a single
        value but we aren't validating string vs. integer vs. boolean because
        cluster properties can range the gambit.)
    end

    autorequire(:service) do
      ['corosync']
    end

    validate do
      break if parameter(:ensure) and parameter(:ensure).value == :absent
      fail 'Option "value" is required!' unless parameter :value
    end

  end
end
