# CURTIS config.yml must be in this directory before running the tests

require 'test/unit'
require_relative '../harambe.rb'

class PeopoleTests < Test::Unit::TestCase

  def test_twitter_get_profile_url()
    twit = TwitterAPI.new
    actual = twit.get_twitter_acct("Elon Musk")
    assert_equal("https://twitter.com/elonmusk", actual)
  end

  def test_wikipedia_get_url()
    wiki = WikipediaAPI.new
    actual = wiki.get_wikipedia_page("Edsger Dijkstra")
    assert_equal("https://en.wikipedia.org/wiki/Edsger_W._Dijkstra", actual)
  end

end
