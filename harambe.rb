# Hopefully this will deal with most of the other APIs
# Still in ruby, because we aren't bad
require 'json'
require 'koala'
require 'net/http'
require 'twitter'
require 'yaml'

ENV['SSL_CERT_FILE'] = File.open('config.yml') do |f|
  YAML.load(f)['SSLCERTPATH']
end

# make our Facebook calls
class FacebookAPI
  def initialize
    @oauth = auth_facebook_api
    @access_token = @oauth.get_app_access_token
    @graph = Koala::Facebook::API.new(@access_token)
  end

  def get_facebook_page(name)
    res = @graph.search(name, type: :page)
    return "http://facebook.com/#{res[0]['id']}"
  rescue
    return ''
  end

  private

  def auth_facebook_api
    values = []
    %w(FACEBOOKAPPID FACEBOOKSECRET).each do |x|
      File.open('config.yml') { |f| values.push(YAML.load(f)[x]) }
    end
    facebookappid, facebooksecret = values
    Koala::Facebook::OAuth.new(facebookappid, facebooksecret)
  end
end

# make our Twitter calls
class TwitterAPI
  def initialize
    @client = auth_twitter_api
    @requests_sent = 0
  end

  def tweet_the_pole
    @client.update('Check out who is trending today on the new POLE https://coverless.github.io/peopole/')
  end

  # Right now don't go further than page 4 for API usage
  def get_twitter_profile_url(name)
    page_number = 1
    while page_number < 4
      opts = { page: page_number, count: 20 }
      results = @client.user_search("\"#{name}\"", opts)
      results.each do |entry|
        return "https://twitter.com/#{entry.screen_name}" if entry.verified?
      end
      page_number += 1
    end
  end

  def get_twitter_acct(name)
    return get_twitter_profile_url(name)
  rescue
    puts "Apparently #{name} does not have a verified twitter account"
    return ''
  end

  private

  def auth_twitter_api
    values = []
    %w(TWITTERCONSUMERKEY TWITTERCONSUMERSECRET
    TWITTERACCESSTOKEN TWITTERACCESSTOKENSECRET).each do |x|
      File.open('config.yml') { |f| values.push(YAML.load(f)[x]) }
    end
    Twitter::REST::Client.new do |config|
      config.consumer_key, config.consumer_secret,
      config.access_token, config.access_token_secret =
        values
    end
  end
end

# make our Wikipedia calls
class WikipediaAPI
  # Tossing in this fat HACK since I am so frustrated with the SSL errors
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  def get_wikipedia_page(name)
    uri = URI.parse(URI.encode('https://en.wikipedia.org/w/api.php?'\
    "action=opensearch&search=#{name}&limit=1&namespace=0"))
    JSON.parse(Net::HTTP.get(uri))[3][0]
  end
end
