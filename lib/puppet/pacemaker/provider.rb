# the parent provider for all other pacemaker providers
# includes all functions from all submodules

require 'rexml/document'
require 'rexml/formatters/pretty'
require 'timeout'
require 'yaml'

base = File.expand_path File.dirname(__FILE__)

require File.join base, 'cib'
require File.join base, 'constraints'
require File.join base, 'constraint_colocations'
require File.join base, 'constraint_locations'
require File.join base, 'constraint_orders'
require File.join base, 'helpers'
require File.join base, 'nodes'
require File.join base, 'options'
require File.join base, 'primitives'
require File.join base, 'properties'
require File.join base, 'debug'
require File.join base, 'resource_defaults'
require File.join base, 'operation_defaults'
require File.join base, 'status'
require File.join base, 'wait'
require File.join base, 'xml'
require File.join base, 'type'

class Puppet::Provider::Pacemaker < Puppet::Provider

  # include instance methods from the pacemaker library files
  include ::Pacemaker::Cib
  include ::Pacemaker::Constraints
  include ::Pacemaker::ConstraintOrders
  include ::Pacemaker::ConstraintLocations
  include ::Pacemaker::ConstraintColocations
  include ::Pacemaker::Helpers
  include ::Pacemaker::Nodes
  include ::Pacemaker::Options
  include ::Pacemaker::Primitives
  include ::Pacemaker::Properties
  include ::Pacemaker::Debug
  include ::Pacemaker::Resource_defaults
  include ::Pacemaker::Operation_defaults
  include ::Pacemaker::Status
  include ::Pacemaker::Wait
  include ::Pacemaker::Xml
  include ::Pacemaker::Type

  # include class methods from the pacemaker options
  extend  ::Pacemaker::Options

  # reset all mnemoization variables
  # to force pacemaker to reload all the data structures
  # @param comment [String] log file comment tag to trace calls
  def cib_reset(comment=nil)
    message = 'Call: cib_reset'
    message += " (#{comment})" if comment
    debug message

    @cib = nil

    @primitives_structure = nil
    @locations_structure = nil
    @colocations_structure = nil
    @orders_structure = nil
    @node_status_structure = nil
    @cluster_properties_structure = nil
    @nodes_structure = nil
    @resource_defaults_structure = nil
    @operation_defaults_structure = nil
  end

end

# TODO: add pcmk_group type
# TODO: pcmk_location add date_expressions support
# TODO: pcmk_location rules format/validation
# TODO: pcmk_resource convert complex to simple and back
# TODO: pcmk_resource add utilization support
# TODO: cleanup unused methods from pcmk_nodes provider
# TODO: unit tests for location, colocation, order autorequire functions
# TODO: change tests behaviour according to the options and test several possible options
