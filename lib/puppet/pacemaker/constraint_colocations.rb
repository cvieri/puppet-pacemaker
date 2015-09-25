# functions related to colocations constraints
# main structure "constraint_colocations"

module Pacemaker
  module ConstraintColocations

    # get colocation constraints and use mnemoisation on the list
    # @return [Hash<String => Hash>]
    def constraint_colocations
      return @colocations_structure if @colocations_structure
      @colocations_structure = constraints 'rsc_colocation'
    end

    # check if colocation constraint exists
    # @param id [String] the constraint id
    # @return [TrueClass,FalseClass]
    def constraint_colocation_exists?(id)
      constraint_colocations.key? id
    end

    # add a colocation constraint
    # @param colocation_structure [Hash<String => String>] the location data structure
    def constraint_colocation_add(colocation_structure)
      colocation_patch = xml_document
      location_element = xml_rsc_colocation colocation_structure
      fail "Could not create XML patch from colocation '#{colocation_structure.inspect}'!" unless location_element
      colocation_patch.add_element location_element
      cibadmin_create xml_pretty_format(colocation_patch.root), 'constraints'
    end

    # remove a colocation constraint
    # @param id [String] the constraint id
    def constraint_colocation_remove(id)
      cibadmin_delete "<rsc_colocation id='#{id}'/>", 'constraints'
    end

    # generate rsc_colocation elements from data structure
    # @param data [Hash]
    # @return [REXML::Element]
    def xml_rsc_colocation(data)
      return unless data and data.is_a? Hash
      xml_element 'rsc_colocation', data, 'type'
    end

  end
end
