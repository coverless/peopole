# frozen_string_literal: true

require 'twitter'
require 'yaml'

module Platform
  # Interfaces with the Twitter API
  class Twitter
    attr_reader :client

    API_KEYS = %w[
      TWITTERCONSUMERKEY
      TWITTERCONSUMERSECRET
      TWITTERACCESSTOKEN
      TWITTERACCESSTOKENSECRET
    ].freeze
    MAX_PAGES = 7

    def initialize
      @client = setup_twitter
    end

    # This is wrapped in something to check the rate limiting
    # It's not the prettiest but should stop us from breaking
    def account_for(person)
      client.user_search(person).find(&:verified?)&.uri.to_s
    rescue ::Twitter::Error::TooManyRequests => error
      puts 'Too many requests for twitter, sleeping for a bit...'
      sleep(error.rate_limit.reset_in + 1)
      retry
    end

    def count_for(person)
      total_count = 0
      page_number = 0

      begin
        results = client.search(person, result_type: :recent, count: 100)
      rescue ::Twitter::Error::TooManyRequests => error
        handle_rate_limit(error)
        retry
      end

      while results.attrs[:statuses].count.positive? && page_number < MAX_PAGES
        statuses = results.attrs[:statuses]
        total_count += statuses.count
        min_id = statuses.collect { |tweet| tweet[:id] }.min
        begin
          results = client.search(
            person, result_type: :recent, count: 100, max_id: min_id
          )
        rescue ::Twitter::Error::TooManyRequests => error
          handle_rate_limit(error)
          retry
        end
        page_number += 1
      end
      puts "#{person} had #{total_count} tweets"
      total_count
    end

    private

    def handle_rate_limit(error)
      puts 'Too many requests for twitter, sleeping for a bit...'
      sleep(error.rate_limit.reset_in + 1)
    end

    def setup_twitter
      values = []
      File.open('config.yml') do |file|
        vals = YAML.safe_load(file)
        API_KEYS.each do |key|
          values.push(vals[key])
        end
      end
      ::Twitter::REST::Client.new do |config|
        config.consumer_key, config.consumer_secret,
          config.access_token, config.access_token_secret = values
      end
    end
  end
end
