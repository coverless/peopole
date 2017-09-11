# frozen_string_literal: true

require_relative '../../platform/wikipedia'

describe Platform::Wikipedia do
  subject { described_class.new }

  describe '#page_for' do
    it 'returns the correct thing' do
      expect(subject.page_for('Justin Roiland')).to eq('https://en.wikipedia.org/wiki/Justin_Roiland')
    end
  end
end
