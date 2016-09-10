# Hopefully this will deal with most of the other APIs
# Still in ruby, because we aren't bad
require 'json'
require 'koala'
require 'net/http'
require 'twitter'
require 'yaml'

ENV['SSL_CERT_FILE'] = File.open("config.yml") { |f| YAML.load(f)["SSLCERTPATH"] }

class FacebookAPI
  def initialize
    @oauth = auth_facebook_api()
    @access_token = @oauth.get_app_access_token
    @graph = Koala::Facebook::API.new(@access_token)
  end

  def get_facebook_page(name)
    begin
      res = @graph.search(name, type: :page)
      return "http://facebook.com/#{res[0]["id"]}"
    rescue
      return ""
    end
  end

  private
  def auth_facebook_api()
    values = []
    ["FACEBOOKAPPID", "FACEBOOKSECRET"].each do |x|
      File.open("config.yml") { |f| values.push(YAML.load(f)[x]) }
    end
    facebookappid, facebooksecret = values
    return Koala::Facebook::OAuth.new(facebookappid, facebooksecret)
  end

end

class TwitterAPI
  def initialize()
    @client = auth_twitter_api()
    @requests_sent = 0
  end

  def tweet_the_pole()
    @client.update("Check out who is trending today on the new POLE https://coverless.github.io/peopole/")
  end

  # Right now don't go further than page 4 for API usage
  def get_twitter_profile_url(name)
    # In the future we will not need to throttle this API
    if @requests_sent == 0
      @start = Time.now
    end
    page_number = 1
    while (page_number < 4)
      opts = { :page => page_number, :count => 20 }
      results = @client.user_search("\"#{name}\"", opts)
      @requests_sent += 1
      for entry in results
        if entry.verified?
          return "https://twitter.com/#{entry.screen_name}"
        end
      end
      page_number += 1
      if @requests_sent == 180
        @endTime = Time.now
        @requests_sent, @start = check_usage(@start, @endTime)
      end
    end
  end

  def get_twitter_acct(name)
    begin
      return get_twitter_profile_url(name)
    rescue
      puts "Apparently #{name} does not have a verified twitter account"
      return ""
    end
  end

  private
  def auth_twitter_api()
    values = []
    ["TWITTERCONSUMERKEY", "TWITTERCONSUMERSECRET", "TWITTERACCESSTOKEN", "TWITTERACCESSTOKENSECRET"].each do |x|
      File.open("config.yml") { |f| values.push(YAML.load(f)[x]) }
    end
    twitterc, twittercsecret, twittera, twitterasecret = values
    return Twitter::REST::Client.new do |config|
      config.consumer_key = twitterc
      config.consumer_secret = twittercsecret
      config.access_token = twittera
      config.access_token_secret = twitterasecret
    end
  end

  def check_usage(start, endTime)
    if ((endTime - start) < 900)
      puts "\n* WAITING #{((start + 900) - endTime).round(2)} SECONDS *\n\n"
      sleep((start+900) - endTime)
    end
    return 0, Time.now
  end

end

class WikipediaAPI
  # Tossing in this fat HACK since I am so frustrated with the SSL errors
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  def get_wikipedia_page(name)
    uri = URI.parse(URI.encode("https://en.wikipedia.org/w/api.php?action=opensearch&search=#{name}&limit=1&namespace=0"))
    res = JSON.parse(Net::HTTP.get(uri))
    return res[3][0]
  end
end
