# Contains the functionality of peopole
# Done in Ruby, because we aren't bad

# Using the Redd API wrapper for reddit
require 'redd'
require 'json'
require 'yaml'

sslpath = File.open("config.yml") { |f| YAML.load(f)["SSLCERTPATH"]}
ENV['SSL_CERT_FILE'] = sslpath

# Returns an authorized Reddit API
def getRedditAPI
  clientId = File.open("config.yml") { |f| YAML.load(f)["REDDITCLIENTID"]}
  username = File.open("config.yml") { |f| YAML.load(f)["REDDITUSERNAME"]}
  password = File.open("config.yml") { |f| YAML.load(f)["REDDITPASSWORD"]}
  secret = File.open("config.yml") { |f| YAML.load(f)["REDDITSECRET"]}
  r = Redd.it(:script, clientId, secret, username, password, :user_agent => "peopole v1.0.0" )
  r.authorize!
  puts "Redd is authenticated!"
  return r
end

# Makes sure that we are not exceeding 60 requests per minute
# Sleeps if we are going over
# Rounds the output because otherwise team members cannot handle the accuracy!
def checkRequests(start, endTime)
  if ((endTime - start) < 60)
    puts "\n* WAITING #{((start + 60) - endTime).round(2)} SECONDS *\n"
    sleep((start + 60) - endTime)
  end
end

# Returns an array (without \n) of all the people we are searching for
# Used in getResults
def getPeople()
  people = []
  peeps = File.open("people.txt").read
  peeps.each_line do |line|
    people.push(line.gsub!("\n", ""))
  end
  # This is ugly
  return people
end

def countTitles(json, person)
  c = 0
  for i in 0..(json.count - 1)
    # puts json[i]["title"]
    if json[i]["title"].include?(person)
      c += 1
    end
  end
  return c
end

# Does the searching
# Returns an array of people who erred
# => r - the Reddit API wrapper
# => people - the array of people to search
# Writes to results.txt
def performSearch(r, people)
  missed = []
  f = File.open("results.txt", "a")
  start = Time.now; reqCount = 0
  for person in people do
    begin
      totalCount = 0
      # Quotes around the person so that M.I.A isn't top
      res = JSON.parse(r.search("#{person}", :limit => 100, :sort => "top", :t => "day").to_json)
      counter = res.count
      reqCount += 1
      # Check how many there actually are
      # Don't even check if they don't have results
      # TODO -> Find a better threshold
      if res.count > 0
        totalCount += countTitles(res, person)
      end
      # If there is more than one page
      repeat = 1
      while counter == (repeat * 100)
        after = res[99]["name"]
        res = JSON.parse(r.search("#{person}", :limit => 100, :sort => "top", :t => "day", :after => after).to_json)
        reqCount += 1
        counter += res.count
        repeat = repeat + 1
        # Count the titles
        totalCount += countTitles(res, person)
      end

      # Write the results
      f.write("#{person}:#{totalCount}\n")
      puts "#{person} #{totalCount}\n"
      endTime = Time.now

      # Make sure we do not do > 60 requests per minute
      if reqCount == 60
        # checkRequests will sleep if need be
        checkRequests(start, endTime)
        reqCount = 0
        start = Time.now
      end
    rescue
      puts "Presumably 503 Error on #{person}"
      # need to push person with new line?
      missed.push(person)
      puts "\n#{missed}\n\n"
    end
  end
  f.close()
  # Return the array of people who erred out
  return missed
end

# Calls performSearch which writes to results.txt
# AFTER -> Results is full with # of hits, but is not sorted at all
def getResults
  File.delete("results.txt") if File.exists?("results.txt")
  File.delete("withArticles.txt") if File.exists?("withArticles.txt")
  r = getRedditAPI()
  people = getPeople()
  missed = []
  missed = performSearch(r, people)
  puts "Finished first round!"
  while missed.count > 0
    missed = performSearch(r, missed)
  end
  # Sort the results
  system("ruby sort.rb -t")
end

# Sorts the results by # of hits
# Uploads the daily results file to the repo
def sortResults
  # Replace numbers like 51,969 with 51969 (so that we can compare them)
  File.open("clean.txt", "w") do |c|
    File.foreach("results.txt") { |line| x = line.gsub(",", ""); c.write(x) }
  end

  # The array of the top 100 people
  top100 = []

  # Obfuscated and unreadable to make it seem that I know hax
  # Sorts the name by the number of occurences
  File.read("clean.txt")
    .split("\n").sort_by{ |x| both = x.split(":"); -both[1].to_i }  # -both so it is descending, split so that article is disregarded
    .first(100).each{ |entry| top100.push(entry) }

  # Get the articles for the top 100 links
  r = getRedditAPI()
  # This makes a file with the person and articles
  missed = getArticle(r, top100)
  while missed.count > 0
    missed = getArticle(r, missed)
  end

  # Format date to YYYY-MM-DD
  date = Time.new
  day = date.day.to_s.length == 1 ? "0" + date.day.to_s : date.day.to_s
  month = date.month.to_s.length == 1 ? "0" + date.month.to_s : date.month.to_s
  resultsFile = Dir.pwd + "/logs/#{date.year}-#{month}-#{day}.txt"
  File.open(resultsFile, "w") do |f|
    File.read("withArticles.txt")
      .split("\n").sort_by{ |x| both = x.split(":"); -both[1].split(";")[0].to_i }
      .first(100).each { |entry| f.write(entry + "\n") }
  end

  # Push the results to the repo
  # Using this would cause commit errors until we take 'logs/' out of the .gitignore
  # TODO - Need to automate providing uname/pwd
  # system("git add #{resultsFile}")
  # system("git commit -m '#{resultsFile}'")
  # system("git push origin master")
end

# Get the most relevant news article for the Top 100
# Returns a list of people erred (similar logic to getResults)
def getArticle(r, top100)
  f = File.open("withArticles.txt", "a")
  missed = []
  start = Time.now; reqCount = 0
  for person in top100 do
  position = 1
    begin
      search = person.split(":")[0]
      res = JSON.parse(r.search("#{search}", :limit => 1, :sort => "top", :t => "week").to_json)
      reqCount += 1
      puts "Getting article for #{position}. #{person}"
      position += 1
      url = res[0]["url"]

      f.write("#{person};#{url}\n")
      endTime = Time.now
      # Make sure we do not do > 60 requests per minute
      if reqCount == 60
        # checkRequests will sleep if need be
        checkRequests(start, endTime)
        reqCount = 0
        start = Time.now
      end
    rescue
      puts "503 on #{search}"
      missed.push(person)
    end
  end
  f.close()
  return missed
end

# Sort people.txt alphabetically
def sortPeople
  sorted = File.readlines("people.txt").sort
  File.open("people.txt", "w") do |f|
    sorted.each do |entry|
      f.write(entry)
    end
  end
end


######################
######## MAIN ########
######################

if ARGV[0] == "-p"
  sortPeople
elsif ARGV[0] == "-t"
  sortResults
elsif ARGV[0] == "-g"
  getResults
else
  puts "\nUSAGE: run 'ruby sort' with one of the following parameters"
  puts "\t-g (get the results)"
  puts "\t-t (sort the results by # of tweets and get the related article)"
  puts "\t-p (sort people.txt alphabetically)"
end
