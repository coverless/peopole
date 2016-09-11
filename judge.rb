#!C:\Ruby23\bin ruby
# Contains the functionality of peopole
# Done in Ruby, because we aren't bad

# Using the Redd API wrapper for reddit
require 'date'
require 'json'
require 'net/http'
require 'redd'
require 'yaml'
require_relative 'dirtybit.rb'
require_relative 'harambe.rb'

ENV['SSL_CERT_FILE'] = File.open("config.yml") { |f| YAML.load(f)["SSLCERTPATH"] }
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
  ["results.txt", "withArticles.txt"].each { |x| File.delete(x) if File.exists?(x) }
  elapsedStart = Time.now
  r = getRedditAPI()
  people = getPeople()
  missed = performSearch(r, people)
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
  # Sorts the name by the number of hits
  top50 = []
  File.read("clean.txt")
    .split("\n").sort_by{ |x| both = x.split(":"); -both[1].to_i }  # -both so it is descending
    .first(50).each{ |entry| top50.push(entry) }

  # Get the articles for the top 50 links
  # This makes a file with the person and articles (withArticles.txt)
  r = getRedditAPI()
  missed = getArticle(r, top50)
  while missed.count > 0
    missed = getArticle(r, missed)
  end

  db = DB.new
  # Format date to YYYY-MM-DD
  # date = Date.today
  # day = getDate(date.day)
  # month = getDate(date.month)
  # today = "#{date.year}-#{month}-#{day}"
  # resultsFile = File.join(Dir.pwd, "logs", "#{today}.txt")
  rank = 1
  # File.open(resultsFile, "w") do |f|
  File.read("withArticles.txt")
    .split("\n")
    .first(50).each do |entry|
      f.write(entry + "\n")
      db.add_ranking(
        JSON.parse(entry)["name"],
        JSON.parse(entry)["article_title"],
        JSON.parse(entry)["article_url"],
        rank
      )
      rank += 1
    end
  # end

  # Push the results to the repo and update the site
  # The working directory needs to be clean for this to work!
  # system("git add #{resultsFile}")
  # system("git commit -m #{date.year}-#{month}-#{day}")
  # system("git push origin master")
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
        puts "There are results ... Getting valid hits"
        nameMatches = getNames(person)
        totalCount += countTitles(res, nameMatches)
        repeat = 1
        # For more than one page
        while counter == (repeat * 100)
          after = res[99]["name"]
          res = JSON.parse(r.search("#{person}", :limit => 100, :sort => "top", :t => "day", :after => after).to_json)
          reqCount += 1
          counter += res.count
          repeat += 1
          totalCount += countTitles(res, nameMatches)
        end
      end

      # Write the results
      f.write("#{person}:#{totalCount}\n")
      puts "#{person} #{totalCount}\n\n"
      endTime = Time.now

      # Make sure we do not do > 60 requests per minute
      if reqCount == REDDIT_API_LIMIT
        reqCount, start = checkApiUsage(start, endTime)
      end
    rescue
      puts "Presumably 503 Error on #{person}"
      sleep(2)
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
# TODO -> Breaks order if a person errs! Also breaks their relative ranking!
def getArticle(r, top50)
  farooKey = File.open("config.yml") { |f| YAML.load(f)["FAROOKEY"]}
  f = File.open("withArticles.txt", "a")
  missed = []
  position = 1
  db = DB.new
  facebook = FacebookAPI.new
  twitter = TwitterAPI.new
  wikipedia = WikipediaAPI.new
  ranking = 1
  for person in top50 do
    begin
      search = person.split(":")[0]
      uri = URI.parse(URI.encode("http://www.faroo.com/api?q=#{search}&src=news&key=#{farooKey}"))
      res = JSON.parse(Net::HTTP.get(uri))
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
      puts "Getting article for #{position}. #{search}"
      position += 1
      information = {}
      information["name"] = search
      information["article_title"] = title
      information["article_url"] = article
      # Later on, we should search for the ones that don't have values
      # Right now we only search if none of them are populated
      fpage, tpage, wpage = db.get_person_links(search)
      if fpage.nil? && tpage.nil? && wpage.nil?
        fpage = facebook.get_facebook_page(search)
        tpage = twitter.get_twitter_acct(search)
        wpage = wikipedia.get_wikipedia_page(search)
        db.add_person_links(search, fpage, tpage, wpage)
      end
      information["facebook"] = fpage
      information["twitter"] = tpage
      information["wikipedia"] = wpage
      to_file = information.to_json
      f.write("#{to_file}\n")
      # So we do not exceed the rate limit and Faroo doesn't flip
      ranking += 1
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
  people = people.uniq.sort
  File.open("people.txt", "w") do |f|
    people.each { |x| if adding.include?(x) then puts "Added #{x}" end; f.write(x) }
  end
end

##############################################
#            CLEAN UP PEOPLE                 #
# => Deletes anyone who hasn't been          #
# mentioned in one month                     #
##############################################
# TODO - We may never use this
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
      res.count.zero? ? (puts "#{person} has NOT made the cut!";c.write("#{person}\n");next)
       : (puts "#{person} has MADE the cut!";madeTheCut.push(person))
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
    del.include?(entry.downcase) ? (puts "Deleting #{entry}";next) : updated.push(entry)
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
  values = []
  ["REDDITCLIENTID", "REDDITUSERNAME", "REDDITPASSWORD", "REDDITSECRET"].each do |x|
    File.open("config.yml") { |f| values.push(YAML.load(f)[x]) }
  end
  clientId, username, password, secret = values
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
  json.each { |title| person.any? { |m| if m.match(title["title"]) then c += 1 end } }
  return c
end

# We can add specific rules as methods later (the Dr. Dre case)
def getNames(person)
  # Make sure that there is non alphanumeric after their name
  result = [/#{person}\W/]
  # Deal with the possessive case
  person[-1] == "s" ? result.push(/#{person}'\W/) : result.push(/#{person}'s\W/)
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
