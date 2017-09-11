# frozen_string_literal: true

require 'koala'
require 'yaml'

module Platform
  # Interfaces with Facebook
  class Facebook
    API_KEYS = %w[FACEBOOKAPPID FACEBOOKSECRET].freeze
    ROOT_URI = 'https://www.facebook.com'

    attr_reader :client

    def initialize
      @oauth = auth_facebook
      @access_token = @oauth.get_app_access_token
      @client = Koala::Facebook::API.new(@access_token)
    end

    def page_for(person)
      "#{ROOT_URI}/#{@client.search(person, type: :page).first['id']}"
    end

    private

    def auth_facebook
      values = []
      File.open('config.yml') do |file|
        vals = YAML.safe_load(file)
        API_KEYS.each do |key|
          values.push(vals[key])
        end
      end
      id, secret = values
      Koala::Facebook::OAuth.new(id, secret)
    end
  end
end
