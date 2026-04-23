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
      let(:query_string) { 'userName eq "taro"' }
      it { expect(parser.operator).to eq '=' }
    end

    context 'ne' do
      let(:query_string) { 'userName ne "taro"' }
      it { expect(parser.operator).to eq '!=' }
    end

    context 'sw' do
      let(:query_string) { 'userName sw "taro"' }
      it { expect(parser.operator).to eq 'LIKE' }
    end

    context 'gt' do
      let(:query_string) { 'userName gt "taro"' }
      it { expect(parser.operator).to eq '>' }
    end

    context 'ge' do
      let(:query_string) { 'userName ge "taro"' }
      it { expect(parser.operator).to eq '>=' }
    end

    context 'lt' do
      let(:query_string) { 'userName lt "taro"' }
      it { expect(parser.operator).to eq '<' }
    end

    context 'le' do
      let(:query_string) { 'userName le "taro"' }
      it { expect(parser.operator).to eq '<=' }
    end
  end

  describe '#parameter' do
    context 'no manipulation' do
      let(:query_string) { 'userName eq "taro"' }
      it { expect(parser.parameter).to eq 'taro' }
    end

    context 'Contains' do
      let(:query_string) { 'userName co "taro"' }
      it { expect(parser.parameter).to eq '%taro%' }
    end

    context 'Starts with' do
      let(:query_string) { 'userName sw "taro"' }
      it { expect(parser.parameter).to eq 'taro%' }
    end

    context 'Ends with' do
      let(:query_string) { 'userName ew "taro"' }
      it { expect(parser.parameter).to eq '%taro' }
    end

    context 'True boolean' do
      let(:query_string) { 'userName eq "True"' }
      it { expect(parser.parameter).to eq true }
    end

    context 'False boolean' do
      let(:query_string) { 'userName eq "FALSE"' }
      it { expect(parser.parameter).to eq false }
    end
  end
end
