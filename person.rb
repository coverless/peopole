# frozen_string_literal: true

require 'digest'

# Represents a person in our system (one that has made the top50)
# We do not create one of these for every person on the list
class Person
  def initialize(name)
    @name = name
    @digest = Digest::MD5.hexdigest(name)
  end

  def social_media_links?(adapter)
    record = adapter.read("people-information/#{@digest}")
    # Check wikipedia for example
    # If they have that entry we have at some point checked for their accounts
    # We need to check each specific account later
    record&.body && record.body['wikipedia']
  end
end
