require 'spec_helper'

describe Puppet::Type.type(:pcmk_order) do
  subject do
    Puppet::Type.type(:pcmk_order)
  end

  it "should have a 'name' parameter" do
    expect(subject.new(
               :name => 'mock_resource',
               :first => 'foo',
               :second => 'bar'
           )[:name]).to eq 'mock_resource'
  end

  describe 'basic structure' do
    it 'should be able to create an instance' do
      expect(subject.new(
                 :name => 'mock_resource',
                 :first => 'foo',
                 :second => 'bar'
             )).to_not be_nil
    end

    [:cib, :name].each do |param|
      it "should have a #{param} parameter" do
        expect(subject.validparameter?(param)).to be_truthy
      end

      it "should have documentation for its #{param} parameter" do
        expect(subject.paramclass(param).doc).to be_a String
      end
    end

    [:first, :second, :score].each do |property|
      it "should have a #{property} property" do
        expect(subject.validproperty?(property)).to be_truthy
      end

      it "should have documentation for its #{property} property" do
        expect(subject.propertybyname(property).doc).to be_a String
      end
    end

    it 'should validate the score values' do
      ['fadsfasdf', '10a', nil].each do |value|
        expect { subject.new(
            :name => 'mock_colocation',
            :first => 'a',
            :second => 'b',
            :score => value
        ) }.to raise_error /score/i
      end
    end

    it 'should change inf to INFINITY in score' do
      expect(subject.new(
                 :name => 'mock_colocation',
                 :first => 'a',
                 :second => 'b',
                 :score => 'inf'
             )[:score]).to eq 'INFINITY'
    end
  end

  describe 'when autorequiring resources' do
    before :each do
      @pcmk_resource = Puppet::Type.type(:pcmk_resource).new(
          :name => 'foo',
          :ensure => :present,
      )
      @csresource_bar = Puppet::Type.type(:pcmk_resource).new(
          :name => 'bar',
          :ensure => :present,
      )
      @pcmk_shadow = Puppet::Type.type(:pcmk_shadow).new(:name => 'baz', :cib => 'baz')
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @pcmk_shadow, @csresource_bar, @pcmk_resource
    end

    it 'should autorequire the corresponding resources' do
      @resource = described_class.new(
          :name => 'dummy',
          :first => 'foo',
          :second => 'bar',
          :cib => 'baz',
          :score => 'inf'
      )
      @catalog.add_resource @resource
      required_resources = @resource.autorequire
      expect(required_resources.size).to eq 3
      required_resources.each do |e|
        expect(e.target).to eq @resource
        expect([@csresource_bar, @pcmk_resource, @pcmk_shadow]).to include e.source
      end
    end

  end
end
