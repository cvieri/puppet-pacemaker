require 'spec_helper'

describe Puppet::Type.type(:pcmk_order).provider(:ruby) do

  let(:resource) { Puppet::Type.type(:pcmk_order).new(
      :name => 'my_order',
      :first => 'p_1',
      :second => 'p_2',
      :score => '200',
      :provider => :ruby,
  ) }

  let(:provider) do
    resource.provider
  end

  before(:each) do
    puppet_debug_override
    provider.stubs(:cluster_debug_report).returns(true)
    provider.stubs(:primitive_exists?).with('p_1').returns(true)
    provider.stubs(:primitive_exists?).with('p_2').returns(true)
  end

  describe('#validation') do
    it 'should fail if there is no first primitive in the CIB' do
      provider.stubs(:primitive_exists?).with('p_1').returns(false)
      provider.create
      expect { provider.flush }.to raise_error "Primitive 'p_1' does not exist!"
    end

    it 'should fail if there is no second primitive in the CIB' do
      provider.stubs(:primitive_exists?).with('p_2').returns(false)
      provider.create
      expect { provider.flush }.to raise_error "Primitive 'p_2' does not exist!"
    end

    it 'should fail if there is no "score" set' do
      resource.delete :score
      provider.create
      expect { provider.flush }.to raise_error 'Data does not contain all the required fields!'
    end
  end

  describe '#update' do
    it 'should update an order' do
      resource[:first] = 'p_1'
      resource[:second] ='p_2'
      provider.stubs(:constraint_order_exists?).returns(true)
      xml = <<-eos
<rsc_order first='p_1' id='my_order' score='200' then='p_2'/>
      eos
      provider.expects(:cibadmin_modify).with xml, 'constraints'
      provider.create
      provider.property_hash[:ensure] = :present
      provider.flush
    end
  end

  describe '#create' do
    it 'should create an order with corresponding members' do
      resource[:first] = 'p_1'
      resource[:second] ='p_2'
      resource[:score] = 'inf'
      xml = <<-eos
<rsc_order first='p_1' id='my_order' score='INFINITY' then='p_2'/>
      eos
      provider.expects(:cibadmin_create).with xml, 'constraints'
      provider.create
      provider.property_hash[:ensure] = :absent
      provider.flush
    end
  end

  describe '#destroy' do
    it 'should destroy order with corresponding name' do
      provider.expects(:cibadmin_delete).with("<rsc_order id='my_order'/>", 'constraints')
      provider.destroy
      provider.flush
    end
  end

end

