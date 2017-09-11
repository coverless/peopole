# frozen_string_literal: true

require_relative '../../platform/guardian'

describe Platform::Guardian do
  subject { described_class.new }

  describe '#count_for' do
    it 'returns something' do
      expect(subject.count_for('Donald')).to be_an Integer
    end
  end
end
