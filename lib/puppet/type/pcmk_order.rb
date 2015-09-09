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

    newparam(:name) do
      desc %q(Name identifier of this ordering entry.  This value needs to be unique
        across the entire Corosync/Pacemaker configuration since it doesn\'t have
        the concept of name spaces per type.)
      isnamevar
    end

    newproperty(:first) do
      desc %q(First Corosync primitive.)
    end

    newproperty(:second) do
      desc %q(Second Corosync primitive.)
    end

    newparam(:cib) do
      desc %q(Corosync applies its configuration immediately. Using a CIB allows
        you to group multiple primitives and relationships to be applied at
        once. This can be necessary to insert complex configurations into
        Corosync correctly.

        This paramater sets the CIB this order should be created in. A
        cs_shadow resource with a title of the same name as this value should
        also be added to your manifest.)
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

    autorequire(:pcmk_shadow) do
      [parameter(:cib).value] if parameter :cib
    end

    autorequire(:service) do
      ['corosync']
    end

    autorequire(:pcmk_resource) do
      autos = []
      autos << parameter(:first).value if parameter :first
      autos << parameter(:second).value if parameter :second
      autos
    end

  end
end
