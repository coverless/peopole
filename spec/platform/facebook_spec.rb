# frozen_string_literal: true

require_relative '../../platform/facebook'

describe Platform::Facebook do
  subject { described_class.new }

  describe '#page_for' do
    let(:expected) { 'https://www.facebook.com/67985126744' }
    it 'returns the correct thing' do
      expect(subject.page_for('Adult Swim')).to eq(expected)
    end
  end
end
