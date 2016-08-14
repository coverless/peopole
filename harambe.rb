# Hopefully this will deal with most of the other APIs
# Still in ruby, because we aren't bad
require 'yaml'
require 'twitter'
require 'wikipedia'

ENV['SSL_CERT_FILE'] = File.open("config.yml") { |f| YAML.load(f)["SSLCERTPATH"] }

class TwitterAPI
  def initialize()
    # This shouldn't need to happen
    ENV['SSL_CERT_FILE'] = File.open("config.yml") { |f| YAML.load(f)["SSLCERTPATH"] }
    @client = auth_twitter_api()
  end

  def tweet_the_pole()
    @client.update("Check out who is trending today on the new POLE https://coverless.github.io/peopole/")
  end

  def get_twitter_profile_url(name)
    page_number = 1
    while
      opts = { :page => page_number, :count => 20 }
      results = @client.user_search("\"#{name}\"", opts)
      for entry in results
        if entry.verified?
          return "https://twitter.com/#{entry.screen_name}"
        end
      end
      page_number += 1
    end
  end

  def twitter_acct(name)
    begin
      return get_twitter_profile_url(name)
    rescue
      return "Apparently #{name} does not have a verified twitter account"
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

end

class WikipediaAPI
  def get_wikipedia_url(name)
    return Wikipedia.find(name).fullurl
  end
end
