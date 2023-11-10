# frozen_string_literal: true

require 'spec_helper'

describe Scimaenaga::ScimQueryParser do
  let(:query_string) { 'userName eq "taro"' }
  let(:queryable_attributes) do
    {
      userName: :name,
      emails: [
        {
          value: :email,
        }
      ],
    }
  end
  let(:parser) { described_class.new(query_string, queryable_attributes) }

  describe '#attribute' do
    context 'userName' do
      it { expect(parser.attribute).to eq :name }
    end

    context 'emails[type eq "work"].value' do
      let(:query_string) { 'emails[type eq "work"].value eq "taro@example.com"' }
      it { expect(parser.attribute).to eq :email }
    end
  end

  describe '#operator' do
    context 'eq' do
      it { expect(parser.operator).to eq '=' }
    end

    context 'ne' do
      described_class.new('userName ne "taro"', queryable_attributes)
      it { expect(parser.operator).to eq '!=' }
    end

    context 'sw' do
      described_class.new('userName sw "taro"', queryable_attributes)
      it { expect(parser.operator).to eq 'LIKE' }
    end

    context 'gt' do
      described_class.new('userName gt "taro"', queryable_attributes)
      it { expect(parser.operator).to eq '>' }
    end

    context 'ge' do
      described_class.new('userName ge "taro"', queryable_attributes)
      it { expect(parser.operator).to eq '>=' }
    end

    context 'lt' do
      described_class.new('userName lt "taro"', queryable_attributes)
      it { expect(parser.operator).to eq '<' }
    end

    context 'le' do
      described_class.new('userName le "taro"', queryable_attributes)
      it { expect(parser.operator).to eq '<=' }
    end
  end

  describe '#parameter' do
    context 'no manipulation' do
      it { expect(parser.perameter).to eq "taro" }
    end

    context 'Contains' do
      described_class.new('userName co "taro"', queryable_attributes)
      it { expect(parser.perameter).to eq '%taro%' }
    end

    context 'Starts with' do
      described_class.new('userName sw "taro"', queryable_attributes)
      it { expect(parser.perameter).to eq 'taro%' }
    end

    context 'Ends with' do
      described_class.new('userName ew "taro"', queryable_attributes)
      it { expect(parser.perameter).to eq '%taro' }
    end

    context 'True boolean' do
      described_class.new('userName eq "True"', queryable_attributes)
      it { expect(parser.perameter).to eq true }
    end

    context 'False boolean' do
      described_class.new('userName eq "FALSE"', queryable_attributes)
      it { expect(parser.perameter).to eq false }
    end
  end
end
