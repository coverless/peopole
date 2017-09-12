# frozen_string_literal: true

require_relative '../../platform/twitter'

describe Platform::Twitter do
  let(:twitter_platform) { described_class.new }

  describe '#account_for' do
    subject { twitter_platform.account_for(person) }

    context 'when a verified account exists' do
      let(:person) { 'Dillon Francis' }
      let(:expected) { 'https://twitter.com/DILLONFRANCIS' }

      it 'returns the correct account' do
        expect(subject).to eq(expected)
      end
    end

    context 'when there is no verified account' do
      let(:person) { 'blueyhuey' }
      let(:expected) { '' }

      it 'returns an empty string' do
        expect(subject).to eq(expected)
      end
    end
  end

  describe '#count_for' do
    it 'returns an integer' do
      expect(twitter_platform.count_for('Rick and Morty')).to be_an Integer
    end
  end
end
