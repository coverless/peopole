# frozen_string_literal: true

require_relative 'platform/guardian'
require_relative 'platform/twitter'

# Includes the other platforms to aggregate results
# Each of these add scores based on some (TBD) weight
class Aggregator
  def initialize
    @services = [Platform::Guardian.new, Platform::Twitter.new]
  end

  def aggregate(list)
    list.map do |person, count|
      added_score = 0
      @services.each do |service|
        # Weights are defined in each platform
        added_score += service.count_for(person)
      end
      [person, count + added_score]
    end.to_h
  end
end
