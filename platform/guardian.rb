# frozen_string_literal: true

require 'yaml'
require 'net/http'
require 'json'
require 'date'

module Platform
  # Interfaces with The Guardian
  # This is another source to complement the Reddit numbers
  # At some point I will make this into a gem
  class Guardian
    API_KEY = 'GUARDIANKEY'

    URI = 'http://content.guardianapis.com/search?'

    def initialize
      @key = setup_guardian
    end

    def count_for(person)
      url = "#{URI}q=#{person}&from-date=#{Date.today.prev_day}&api-key=#{@key}"
      JSON.parse(Net::HTTP.get(URI(url)))['response']['total']
    end

    private

    def setup_guardian
      YAML.safe_load(File.read('config.yml'))[API_KEY]
    end
  end
end
