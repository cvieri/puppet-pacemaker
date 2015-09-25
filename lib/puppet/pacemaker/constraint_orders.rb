# functions related to constraint_orders constraints
# main structure "constraint_orders"

module Pacemaker
  module ConstraintOrders

    # get order constraints and use mnemoisation on the list
    # @return [Hash<String => Hash>]
    def constraint_orders
      return @orders_structure if @orders_structure
      @orders_structure = constraints 'rsc_order'
    end

    # check if order constraint exists
    # @param id [String] the constraint id
    # @return [TrueClass,FalseClass]
    def constraint_order_exists?(id)
      constraint_orders.key? id
    end

    # remove an order constraint
    # @param id [String] the constraint id
    def constraint_order_remove(id)
      cibadmin_delete "<rsc_order id='#{id}'/>", 'constraints'
    end

    # add a order constraint
    # @param colocation_structure [Hash<String => String>] the location data structure
    def constraint_order_add(colocation_structure)
      colocation_patch = xml_document
      location_element = xml_rsc_colocation colocation_structure
      fail "Could not create XML patch from colocation '#{colocation_structure.inspect}'!" unless location_element
      colocation_patch.add_element location_element
      cibadmin_create xml_pretty_format(colocation_patch.root), 'constraints'
    end

    # generate rsc_order elements from data structure
    # @param data [Hash]
    # @return [REXML::Element]
    def xml_rsc_order(data)
      return unless data and data.is_a? Hash
      xml_element 'rsc_order', data, 'type'
    end

  end
end
