# frozen_string_literal: true

require_relative '../../platform/twitter'

describe Platform::Twitter do
  subject { described_class.new }

  describe '#account_for' do
    let(:expected) { 'https://twitter.com/DILLONFRANCIS' }
    it 'returns the correct account' do
      expect(subject.account_for('Dillon Francis')).to eq(expected)
    end
  end

  describe '#count_for' do
    it 'returns an integer' do
      expect(subject.count_for('Rick and Morty')).to be_an Integer
    end
  end
end
