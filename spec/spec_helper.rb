require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |config|
  config.mock_framework = :mocha
end

def puppet_debug_override
  return unless ENV['SPEC_PUPPET_DEBUG']
  Puppet::Util::Log.level = :debug
  Puppet::Util::Log.newdestination(:console)
end
