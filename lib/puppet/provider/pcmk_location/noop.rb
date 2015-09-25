require File.join File.dirname(__FILE__), '../../pacemaker/noop'

Puppet::Type.type(:pcmk_location).provide(:noop, :parent => Puppet::Provider::Noop) {}
