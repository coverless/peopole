# frozen_string_literal: true

require 'wikipedia'

module Platform
  # Interfaces with Wikipedia
  class Wikipedia
    # Just a dummy method so that the interface stays the same as others
    def initialize; end

    # Probably should do some sort of checking that this is in fact the correct
    # one. For instance, check the page type, maybe even content
    def page_for(person)
      ::Wikipedia.find(person).fullurl
    end
  end
end
