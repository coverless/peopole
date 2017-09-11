# frozen_string_literal: true

require_relative 'platform/facebook'
require_relative 'platform/twitter'
require_relative 'platform/wikipedia'

# This feels like a relatively weird class but it will be fine...
class SocialMedia
  def initialize
    @twitter = Platform::Twitter.new
    @wikipedia = Platform::Wikipedia.new
    @facebook = Platform::Facebook.new
  end

  # Returns a hash
  def links_for(person)
    hash = {}
    hash[:name] = person
    hash[:twitter] = @twitter.account_for(person)
    hash[:wikipedia] = @wikipedia.page_for(person)
    hash[:facebook] = @facebook.page_for(person)
    p hash
    hash
  end
end
