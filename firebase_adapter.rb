# frozen_string_literal: true

require 'firebase'
require 'yaml'

# Interfaces with the Firebase API
class FirebaseAdapter
  URI = 'https://peopole-fig.firebaseio.com/'
  API_KEY = 'FIREBASESECRET'

  attr_reader :client

  def initialize
    @client = Firebase::Client.new(URI, firebase_secret)
  end

  # `data` better be a hash
  # Possibly add timestamps to everything
  def write(endpoint, data, id = nil)
    @client.set("#{endpoint}/#{id}", data)
    puts "Sent #{data}!"
  end

  def read(endpoint)
    @client.get(endpoint)
  end

  private

  def firebase_secret
    File.open('config.yml') do |file|
      return YAML.safe_load(file)[API_KEY]
    end
  end
end
