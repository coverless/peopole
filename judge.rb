# Contains the functionality of peopole
# Done in Ruby, because we aren't bad

# Using the Redd API wrapper for reddit
require 'redd'
require 'json'
require 'yaml'
require 'net/http'

sslpath = File.open("config.yml") { |f| YAML.load(f)["SSLCERTPATH"]}
ENV['SSL_CERT_FILE'] = sslpath

# The maximum number of requests we can send in a minute
REDDIT_API_LIMIT = 60

############################################
#              GET RESULTS (-g)            #
# => Calls performSearch which writes to   #
# results.txt                              #
# => sortResults is called after and       #
# writes the results to today's log        #
############################################
def getResults
  File.delete("results.txt") if File.exists?("results.txt")
  File.delete("withArticles.txt") if File.exists?("withArticles.txt")
  elapsedStart = Time.now
  r = getRedditAPI()
  people = getPeople()
  missed = []
  missed = performSearch(r, people)
  puts "Finished first round!"
  while missed.count > 0
    missed = performSearch(r, missed)
  end
  elapsedEnd = Time.now
  puts "\nTOTAL TIME #{((elapsedEnd - elapsedStart)/60).truncate} MINUTES\n\n"
  # Sort the results (calls sortResults)
  system("ruby judge.rb -t")
end

############################################
#            SORT RESULTS (-t)             #
# => Sorts the results by # of hits        #
# and writes the results to the log file   #
# TODO -> make the upload automated        #
############################################
def sortResults
  # Replace numbers like 51,969 with 51969 (so that we can compare them)
  File.open("clean.txt", "w") do |c|
    File.foreach("results.txt") { |line| x = line.gsub(",", ""); c.write(x) }
  end

  # Obfuscated and unreadable to make it seem that I know hax
  # Sorts the name by the number of occurences
  top100 = []
  File.read("clean.txt")
    .split("\n").sort_by{ |x| both = x.split(":"); -both[1].to_i }  # -both so it is descending
    .first(100).each{ |entry| top100.push(entry) }

  # Get the articles for the top 100 links
  # This makes a file with the person and articles (withArticles.txt)
  r = getRedditAPI()
  missed = getArticle(r, top100)
  while missed.count > 0
    missed = getArticle(r, missed)
  end

  # Format date to YYYY-MM-DD
  date = Time.new
  day = getDate(date.day)
  month = getDate(date.month)
  resultsFile = File.join(Dir.pwd, "logs", "#{date.year}-#{month}-#{day}.txt")
  File.open(resultsFile, "w") do |f|
    File.read("withArticles.txt")
      .split("\n").sort_by{ |x| both = x.split(":"); -both[1].split("`")[0].to_i }
      .first(100).each { |entry| f.write(entry + "\n") }
  end

  # Push the results to the repo and update the site
  # The working directory needs to be clean for this to work!
  # TODO - Need to automate providing uname/pwd
  system("git add #{resultsFile}")
  system("git commit -m #{date.year}-#{month}-#{day}")
  system("git push origin master")
  system("bundle exec rake publish")
end


##############################################
#             PERFORM SEARCH                 #
# => Used in getResults. Returns an array of #
# people who erred. Keeps being called       #
# "recursively" until no more people have    #
# erred. Writes to results.txt               #
# => r - the Reddit API wrapper              #
# => people - the array of people to search  #
##############################################
def performSearch(r, people)
  missed = []
  f = File.open("results.txt", "a")
  start = Time.now; reqCount = 0
  for person in people do
    begin
      totalCount = 0
      res = JSON.parse(r.search("#{person}", :limit => 100, :sort => "top", :t => "day").to_json)
      reqCount += 1
      counter = res.count
      if !counter.zero?
        nameMatches = getNames(person)
        totalCount += countTitles(res, nameMatches)
        repeat = 1
        # For more than one page
        while counter == (repeat * 100)
          after = res[99]["name"]
          res = JSON.parse(r.search("#{person}", :limit => 100, :sort => "top", :t => "day", :after => after).to_json)
          reqCount += 1
          counter += res.count
          repeat = repeat + 1
          totalCount += countTitles(res, nameMatches)
        end
      end

      # Write the results
      f.write("#{person}:#{totalCount}\n")
      puts "#{person} #{totalCount}\n"
      endTime = Time.now

      # Make sure we do not do > 60 requests per minute
      # checkApiUsage will sleep if need be
      if reqCount == REDDIT_API_LIMIT
        reqCount, start = checkApiUsage(start, endTime)
      end
    rescue
      puts "Presumably 503 Error on #{person}"
      missed.push(person)
    end
  end
  f.close()
  return missed
end

##############################################
#               GET ARTICLES                 #
# => Used in getResults. Returns an array of #
# people who erred. Keeps being called       #
# "recursively" until no more people have    #
# erred. Writes to withArticles.txt          #
# => r - the Reddit API wrapper              #
# => people - the array of people to search  #
##############################################
# TODO -> Breaks order if a person errs
def getArticle(r, top100)
  farooKey = File.open("config.yml") { |f| YAML.load(f)["FAROOKEY"]}
  f = File.open("withArticles.txt", "a")
  missed = []
  position = 1
  for person in top100 do
    begin
      search = person.split(":")[0]
      u = URI.encode("http://www.faroo.com/api?q=#{search}&src=news&key=#{farooKey}&f=json")
      uri = URI.parse(u)
      response = Net::HTTP.get(uri)
      res = JSON.parse(response)
      # TODO -> clean this up, and if there are no results this will break
      name = getNames(search)
      for a in res["results"]
        for n in name
          if n.match(a["title"])
            title = a["title"].chomp
            article = a["url"].chomp
            break
          end
        end
        if title
          break
        end
      end
      #title = res["results"][0]["title"].chomp
      #article = res["results"][0]["url"].chomp
      puts "Getting article for #{position}. #{search}"
      position += 1
      f.write("#{search}`#{title}`#{article}\n")
      # So we do not exceed the rate limit and Faroo doesn't flip
      sleep(3)
    # TODO -> don't rescue from Exception
    rescue Exception => e
      puts e
      missed.push(person)
    end
  end
  f.close()
  return missed
end

##############################################
#               ADD PEOPLE                   #
# => Adds people from toAdd.txt to           #
# people.txt. Does not add duplicates        #
##############################################
# TODO this is sketchy. Needs to sort people at the end?
def addPeople
  f = File.open("toAdd.txt", "r")
  toadd = []
  f.each_line do |line|
    toadd.push(line)
  end
  f.close()
  # Make sure there is a new line on the last entry
  toadd[-1].gsub!("\n", "")
  toadd[-1] += "\n"

  f = File.open("people.txt", "r")
  people = []
  f.each_line do |line|
    people.push(line)
  end
  f.close()
  # need clone so that can do delete()?
  adding = toadd.clone
  # If people doesn't have this person then add them to the people list
  toadd.each { |x| if people.include?(x) then adding.delete(x); puts "#{x.strip()} is already part of the list!" else people.push(x) end }
  # Delete duplicates and sort
  people.uniq!
  people.sort!
  File.open("people.txt", "w") do |f|
    people.each { |x| if adding.include?(x) then puts "Added #{x}" end; f.write(x) }
  end
end

##############################################
#            CLEAN UP PEOPLE                 #
# => Deletes anyone who hasn't been          #
# mentioned in one month                     #
##############################################
def cleanUpPeople
  # people is the array of all people in the file
  people = getPeople()
  r = getRedditAPI()
  madeTheCut = []
  c = File.open("cut.txt", "w")
  start = Time.now; reqCount = 0
  for person in people do
    begin
      res = JSON.parse(r.search("#{person}", :t => "month").to_json)
      if res.count == 0
        puts "#{person} has NOT made the cut!"
        c.write("#{person}\n")
        next
      else
        puts "#{person} has MADE the cut!"
        madeTheCut.push(person)
      end
      # Make sure we do not do > REDDIT_API_LIMIT requests per minute
      # checkApiUsage will sleep if need be
      if reqCount == REDDIT_API_LIMIT
        reqCount, start = checkApiUsage(start, endTime)
      end
    rescue
      puts "#{person} failed... pretending they passed"
      madeTheCut.push(person)
    end
  end
  c.close()
  # Add the people who have made the cut
  File.open("people.txt", "w") do |f|
    madeTheCut.each { |x| f.write("#{x}\n")}
  end
end

##############################################
#              DELETE PEOPLE                 #
# => Deletes from people.txt (toDelete.txt)  #
##############################################
# TODO - don't care about case
def deletePeople
  del = []
  File.open("toDelete.txt", "r") do |f|
    f.each_line do |line|
      del.push(line.strip.downcase)
    end
  end
  people = getPeople()
  # The people who should not be deleted
  updated = []
  people.each do |entry|
    if del.include? (entry.downcase)
      puts "Deleting #{entry}"
      next
    else
      updated.push(entry)
    end
  end
  File.open("people.txt", "w") do |f|
    updated.each { |x| f.write("#{x}\n")}
  end
end

############################################
#            Boring Utility Stuff          #
############################################

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

# Sleeps if we make > REDDIT_API_LIMIT per minute
# Rounds the output because otherwise team members cannot handle the accuracy!
def checkApiUsage(start, endTime)
  if ((endTime - start) < 60)
    puts "\n* WAITING #{((start + 60) - endTime).round(2)} SECONDS *\n\n"
    sleep((start + 60) - endTime)
  end
  # Reset the 'counting' values
  return 0, Time.now
end

# Parses the returned JSON and only increments the count
# for articles that include the person's name in the article title
def countTitles(json, person)
  c = 0
  for i in 0..(json.count - 1)
    for m in person
      if m.match(json[i]["title"])
        c += 1
        break
      end
    end
  end
  return c
end

# We can add specific rules as methods later (the Dr. Dre case)
def getNames(person)
  # Make sure that there is non alphanumeric after their name
  result = [/#{person}\W/]
  # Deal with the possessive case
  if person[-1] == "s"
    result.push(/#{person}'\W/)
  else
    result.push(/#{person}'s\W/)
  end
  print result
  return result
end

# Makes date, give it two digits if it needs it
def getDate(date)
  date < 10 ? "0#{date}" : date
end

# Returns an array (without \n) of all the people we are searching for
def getPeople()
  people = []
  peeps = File.open("people.txt").read
  peeps.each_line do |line|
    people.push(line.gsub!("\n", ""))
  end
  return people
end

# Sort people.txt alphabetically
def sortPeople
  sorted = File.readlines("people.txt").sort
  File.open("people.txt", "w") { |f| sorted.each do |entry| f.write(entry) end }
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
elsif ARGV[0] == "-a"
  addPeople
elsif ARGV[0] == "-c"
  cleanUpPeople
elsif ARGV[0] == "-d"
  deletePeople
elsif ARGV[0] == "-force"
  getArticle(getRedditAPI(), [])
else
  puts "\nUSAGE: run 'ruby judge' with one of the following parameters"
  puts "\t-g (get the results)"
  puts "\t-t (sort the results by # of tweets and get the related article)"
  puts "\t-p (sort people.txt alphabetically)"
  puts "\t-a (add people from toAdd.txt)"
  puts "\t-c (cleanup people with no results in the last month )"
  puts "\t-d (delete people from toDelete.txt)"
end
