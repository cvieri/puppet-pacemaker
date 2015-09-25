require 'spec_helper'

describe Puppet::Type.type(:pcmk_colocation).provider(:ruby) do

  let(:resource) { Puppet::Type.type(:pcmk_colocation).new(
      :name => 'my_colocation',
      :first => 'foo',
      :second => 'bar',
      :provider => :ruby,
  ) }

  let(:provider) do
    resource.provider
  end

  before(:each) do
    puppet_debug_override
    provider.stubs(:cluster_debug_report).returns(true)
    provider.stubs(:constraint_colocation_exists?).returns(false)
    provider.stubs(:primitive_exists?).with('foo').returns(true)
    provider.stubs(:primitive_exists?).with('bar').returns(true)
  end

  describe('#validation') do
    it 'should fail if there is no first primitive in the CIB' do
      provider.stubs(:primitive_exists?).with('foo').returns(false)
      provider.create
      expect { provider.flush }.to raise_error "Primitive 'foo' does not exist!"
    end

    it 'should fail if there is no second primitive in the CIB' do
      provider.stubs(:primitive_exists?).with('bar').returns(false)
      provider.create
      expect { provider.flush }.to raise_error "Primitive 'bar' does not exist!"
    end

    it 'should fail if there is no "score" set' do
      resource.delete :score
      provider.create
      expect { provider.flush }.to raise_error 'Data does not contain all the required fields!'
    end
  end

  describe '#update' do
    it 'should update a colocation' do
      resource[:score] = '200'
      provider.stubs(:constraint_colocation_exists?).returns(true)
      xml = <<-eos
<rsc_colocation id='my_colocation' rsc='bar' score='200' with-rsc='foo'/>
      eos
      provider.expects(:cibadmin_modify).with xml, 'constraints'
      provider.create
      provider.property_hash[:ensure] = :present
      provider.flush
    end
  end

  describe '#create' do
    it 'should create a colocation with corresponding members' do
      resource[:score] = 'inf'

      xml = <<-eos
<rsc_colocation id='my_colocation' rsc='bar' score='INFINITY' with-rsc='foo'/>
      eos
      provider.expects(:cibadmin_create).with xml, 'constraints'
      provider.create
      provider.property_hash[:ensure] = :absent
      provider.flush
    end
  end

  describe '#destroy' do
    it 'should destroy colocation with corresponding name' do
      provider.expects(:cibadmin_delete).with "<rsc_colocation id='my_colocation'/>", 'constraints'
      provider.destroy
      provider.flush
    end
  end


end

