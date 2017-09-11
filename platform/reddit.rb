# frozen_string_literal: true

require 'redd'
require 'yaml'

module Platform
  # Interaces with the Reddit API
  # At the moment this is where we get our candidate 100
  class Reddit
    API_KEYS = %w[REDDITCLIENTID REDDITUSERNAME REDDITPASSWORD REDDITSECRET].
               freeze

    MAXIMUM_RESULTS_PER_PAGE = 100

    attr_reader :client

    def initialize
      @client = setup_reddit
    end

    def count_for(person)
      results = @client.search(person, limit: 100, sort: 'top', t: 'day')
      total_count = 0
      loop do
        total_count += count_titles(results, person)
        return total_count unless results.count == MAXIMUM_RESULTS_PER_PAGE
        results = @client.search(
          person,
          limit: MAXIMUM_RESULTS_PER_PAGE,
          sort: 'top',
          t: 'day',
          after: results[-1].name
        )
      end
    end

    private

    # Check that the person's name is in the title
    def count_titles(entries, person_name)
      entries.count { |entry| entry.title.include?(person_name) }
    end

    def setup_reddit
      values = []
      File.open('config.yml') do |file|
        vals = YAML.safe_load(file)
        API_KEYS.each do |key|
          values.push(vals[key])
        end
      end
      id, uname, pword, secret = values
      Redd.it(
        client_id: id,
        secret: secret,
        username: uname,
        password: pword,
        user_agent: 'peopole v2'
      )
    end
  end
end
