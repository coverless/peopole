# Sorts the file by the most results
# Done in Ruby, because we aren't bad

# Using the Redd API wrapper for reddit
require 'redd'
require 'json'
require 'yaml'

sslpath = File.open("config.yml") { |f| YAML.load(f)["SSLCERTPATH"]}
ENV['SSL_CERT_FILE'] = sslpath

# Writes to results.txt
def getResults
  File.delete("results.txt") if File.exists?("results.txt")
  clientId = File.open("config.yml") { |f| YAML.load(f)["REDDITCLIENTID"]}
  username = File.open("config.yml") { |f| YAML.load(f)["REDDITUSERNAME"]}
  password = File.open("config.yml") { |f| YAML.load(f)["REDDITPASSWORD"]}
  secret = File.open("config.yml") { |f| YAML.load(f)["REDDITSECRET"]}

  r = Redd.it(:script, clientId, secret, username, password, :user_agent => "peopole v1.0.0" )
  r.authorize!
  puts "Redd is authenticated!"

  people = getPeople()
  missed = []

  missed = performSearch(r, people)
  puts "Finished first round!"
  while missed.count > 0
    missed = performSearch(r, missed)
  end

  # Sort it next
  system(ruby sort.rb -t)
end

# Does the searching
# Returns an array of people who erred
# => r - the Reddit API wrapper
# => people - the array of people to search
def performSearch(r, people)
  missed = []
  f = File.open("results.txt", "a")
  start = Time.now; reqCount = 0
  for person in people do
    begin
      articleLink = ""
      res = JSON.parse(r.search(person, :limit => 100, :sort => "top", :t => "day").to_json)
      counter = res.count
      reqCount += 1

      # If they are most likely in the top 100
      # TODO -> this news link might not be legit
      if counter > 10 then articleLink = res[0]["url"] end

      # If there is more than one page
      repeat = 1
      while counter == (repeat * 100)
        after = res[99]["name"]
        res = JSON.parse(r.search(person, :limit => 100, :sort => "top", :t => "day", :after => after).to_json)
        reqCount += 1
        counter += res.count
        repeat = repeat + 1
      end
      # Write the results
      f.write("#{person}:#{counter};#{articleLink}\n")
      puts "#{person}\n"
      endTime = Time.now

      # Make sure we do not do > 60 requests per minute
      # TODO -> check mod or reset to 0?
      if reqCount == 60
        if ((endTime - start) < 60) # Less than 60 seconds have passed
          puts "Waiting #{(start + 60) - endTime} seconds"
          sleep((start + 60) - endTime)
        end
        reqCount = 0
        start = Time.now
      end
    rescue
      puts "Presumably 503 Error on #{person}"
      # need to push person with new line?
      missed.push(person)
      puts "\n#{missed}\n"
    end
  end
  f.close()
  # Return the array of people who erred out
  return missed
end

# Returns an array of all the people we are searching for
# TODO -> get rid of the spacing in this method?
# => Make this into a for loop
# For use in getResults
def getPeople()
  people = []
  peeps = File.open("people.txt").read
  peeps.each_line do |line|
    people.push(line.gsub!("\n", ""))
  end
  # This is ugly
  return people
end

# Sorts the results by # of hits
# Uploads the daily results file to the repo
def sortResults
  # Replace numbers like 51,969 with 51969 (so that we can compare them)
  File.open("clean.txt", "w") do |c|
    File.foreach("results.txt") { |line| x = line.gsub(",", ""); c.write(x) }
  end

  # Format date to YYYY-MM-DD
  date = Time.new
  day = date.day.to_s.length == 1 ? "0" + date.day.to_s : date.day.to_s
  month = date.month.to_s.length == 1 ? "0" + date.month.to_s : date.month.to_s

  resultsFile = Dir.pwd + "/logs/#{date.year}-#{month}-#{day}.txt"
  # Obfuscated and unreadable to make it seem that I know hax
  # Writes the sorted results to final.txt
  File.open(resultsFile, "w") do |f|
    File.read("clean.txt")
      .split("\n").sort_by{ |x| both = x.split(":"); -both[1].split(";")[0].to_i }  # -both so it is descending, split so that article is disregarded
      .first(101).each{ |entry| f.write(entry+"\n") }
  end

  # Push the results to the repo
  # Using this would cause commit errors until we take 'logs/' out of the .gitignore
  # TODO - Need to automate providing uname/pwd
  # system("git add #{resultsFile}")
  # system("git commit -m '#{resultsFile}'")
  # system("git push origin master")
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

if ARGV[0] == "-p"
  sortPeople
elsif ARGV[0] == "-t"
  sortResults
elsif ARGV[0] == "-g"
  getResults
else
  puts "\nUSAGE: run 'ruby sort' with one of the following parameters"
  puts "\t-g (get the results)"
  puts "\t-t (sort the results by # of tweets)"
  puts "\t-p (sort people.txt alphabetically)"
end
