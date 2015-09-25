require File.join File.dirname(__FILE__), '../../pacemaker/noop'

Puppet::Type.type(:pcmk_resource_default).provide(:noop, :parent => Puppet::Provider::Noop) {}
