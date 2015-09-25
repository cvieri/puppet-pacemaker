require File.join File.dirname(__FILE__), '../../pacemaker/noop'

Puppet::Type.type(:service).provide(:noop, :parent => Puppet::Provider::Noop) {}
