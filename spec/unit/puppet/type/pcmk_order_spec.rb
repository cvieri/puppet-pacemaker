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

    [:name].each do |param|
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

end
