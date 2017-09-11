# frozen_string_literal: true

require 'json'
require 'digest'
require 'date'
require_relative 'aggregator'
require_relative 'firebase_adapter'
require_relative 'person'
require_relative 'platform/reddit'
require_relative 'social_media'

# The OG classic, just bigger and stronger
class TheJudge
  THRESHOLD = 15

  def initialize
    @platform = Platform::Reddit.new
    @database = FirebaseAdapter.new
    @social_media = SocialMedia.new
    # Takes the top 100 and checks against other services
    @other_aggregations = Aggregator.new
  end

  # Gets the candidate 100 from Reddit and then runs them through the aggregator
  def post_top_50
    top100 = {}
    list_of_people.each do |person|
      count = @platform.count_for(person)
      next if count < THRESHOLD
      puts "#{person} had #{count} hits!"
      top100[person] = count
    end

    top100aggregate = @other_aggregations.aggregate(top100)
    top50 = top_50_people(top100aggregate)

    post_100(top50)
    social_media_links(top50)
  end

  def post_100(list)
    @database.write(
      'top-50-today',
      names_to_hashes(list),
      Date.today
    )
  end

  # Given the top 50, go get their social media links
  # This is a different endpoint than the top 50
  def social_media_links(top50)
    top50.each do |person, _count|
      next if Person.new(person).social_media_links?(@database)
      @database.write(
        'people-information',
        @social_media.links_for(person),
        Digest::MD5.hexdigest(person)
      )
    end
  end

  private

  def names_to_hashes(list)
    list.map { |person, count| [Digest::MD5.hexdigest(person), count] }.to_h.
      sort_by { |_person, count| -count }.first(50).to_h
  end

  def top_50_people(list)
    list.sort_by { |_person, count| -count }.first(50).to_h
  end

  def list_of_people
    people = []
    File.open('people.txt').read.each_line do |line|
      people.push(line.chomp)
    end
    puts 'Loaded the people!'
    people
  end
end
