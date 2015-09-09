module Pacemaker
  module Cib
    # get the raw CIB from Pacemaker
    # @return [String] cib xml
    def raw_cib
      return File.read @cib_file if @cib_file
      @raw_cib = cibadmin '-Q'
      if !@raw_cib or @raw_cib == ''
        fail 'Could not dump CIB XML!'
      end
      @raw_cib
    end
    attr_accessor :cib_file

    # create a new REXML CIB document
    # @return [REXML::Document] at '/'
    def cib
      return @cib if @cib
      @cib = REXML::Document.new(raw_cib)
    end

    # check id the CIB is retrieved and memorized
    # @return [TrueClass,FalseClass]
    def cib?
      !!@raw_cib
    end

    # add a new XML element to CIB
    # @param xml [String, REXML::Element] XML block to add
    # @param scope [String] XML root scope
    def cibadmin_create(xml, scope)
      xml = xml_pretty_format xml if xml.is_a? REXML::Element
      retry_block do
        options = %w(--force  --sync-call --create)
        options += ['--scope', scope.to_s] if scope
        cibadmin_safe options, '--xml-text', xml.to_s
      end
    end

    # delete the XML element to CIB
    # @param xml [String, REXML::Element] XML block to delete
    # @param scope [String] XML root scope
    def cibadmin_delete(xml, scope)
      xml = xml_pretty_format xml if xml.is_a? REXML::Element
      retry_block do
        options = %w(--force  --sync-call --delete)
        options += ['--scope', scope.to_s] if scope
        cibadmin_safe options, '--xml-text', xml.to_s
      end
    end

    # modify the XML element
    # @param xml [String, REXML::Element] XML element to modify
    # @param scope [String] XML root scope
    def cibadmin_modify(xml, scope)
      xml = xml_pretty_format xml if xml.is_a? REXML::Element
      retry_block do
        options = %w(--force  --sync-call --modify)
        options += ['--scope', scope.to_s] if scope
        cibadmin_safe options, '--xml-text', xml.to_s
      end
    end

    # get the name of the DC node
    # @return [String, nil]
    def dc
      cib_element = cib.elements['/cib']
      return unless cib_element
      dc_node = cib_element.attribute('dc-uuid')
      return unless dc_node
      return if dc_node == 'NONE'
      dc_node.to_s
    end
  end
end