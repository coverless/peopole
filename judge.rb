#!C:\Ruby23\bin ruby
# Contains the functionality of peopole
# Done in Ruby, because we aren't bad

# Using the Redd API wrapper for reddit
require 'date'
require 'fileutils'
require 'json'
require 'net/http'
require 'redd'
require 'yaml'
require_relative 'dirtybit.rb'
require_relative 'harambe.rb'

ENV['SSL_CERT_FILE'] = File.open('config.yml') do |f|
  YAML.load(f)['SSLCERTPATH']
end
# The maximum number of requests we can send in a minute
REDDIT_API_LIMIT = 60

############################################
#              GET RESULTS (-g)            #
# => Calls perform_search which writes to   #
# results.txt                              #
# => sort_results is called after and       #
# writes the results to today's log        #
############################################
def results
  ['results.txt', 'withArticles.txt'].each do |x|
    File.delete(x) if File.exist?(x)
  end
  elapsed_start = Time.now
  r = get_reddit_api
  people = people_list
  missed = perform_search(r, people)
  missed = perform_search(r, missed) while missed.count > 0
  elapsed_end = Time.now
  puts "\nTOTAL TIME #{((elapsed_end - elapsed_start) / 60).truncate} MINUTES\n"
  # Sort the results (calls sort_results)
  system('ruby judge.rb -t')
end

############################################
#            SORT RESULTS (-t)             #
# => Sorts the results by # of hits        #
# and writes the results to the log file   #
# TODO -> make the upload automated        #
############################################
def sort_results
  # Replace numbers like 51,969 with 51969 (so that we can compare them)
  File.open('clean.txt', 'w') do |c|
    File.foreach('results.txt') do |line|
      x = line.delete(',')
      c.write(x)
    end
  end

  # Obfuscated and unreadable to make it seem that I know hax
  # Sorts the name by the number of hits
  top50 = []
  File.read('clean.txt')
      .split("\n").sort_by { |x| both = x.split(':'); -both[1].to_i }
      .first(50).each { |entry| top50.push(entry) }

  # Get the articles for the top 50 links
  # This makes a file with the person and articles (withArticles.txt)
  missed = get_article(top50)
  while missed.count > 0
    missed = get_article(missed)
  end

  db = DB.new
  rank = 1
  db.delete_today
  File.read('withArticles.txt')
      .split("\n")
      .first(50).each do |entry|
        db.add_ranking(
          JSON.parse(entry)['name'],
          JSON.parse(entry)['article_title'],
          JSON.parse(entry)['article_url'],
          rank
        )
        rank += 1
      end
  # The working directory needs to be clean for this to work!
  system('bundle exec rake publish')
  # Delete after publish so that it works next time
  system('rm -rf build')
end

##############################################
#             PERFORM SEARCH                 #
# => Used in results. Returns an array of    #
# people who erred. Keeps being called       #
# "recursively" until no more people have    #
# erred. Writes to results.txt               #
# => r - the Reddit API wrapper              #
# => people - the array of people to search  #
##############################################
def perform_search(r, people)
  missed = []
  f = File.open('results.txt', 'a')
  start = Time.now
  req_count = 0
  people.each do |person|
    begin
      total_count = 0
      res = JSON.parse(r.search(person.to_s, limit: 100, sort: 'top', t: 'day').to_json)
      req_count += 1
      counter = res.count
      if !counter.zero?
        puts 'There are results ... Getting valid hits'
        name_matches = get_names(person)
        total_count += count_titles(res, name_matches)
        repeat = 1
        # For more than one page
        while counter == (repeat * 100)
          after = res[99]['name']
          res = JSON.parse(r.search(person.to_s, limit: 100, sort: 'top', t: 'day', after: after).to_json)
          req_count += 1
          counter += res.count
          repeat += 1
          total_count += count_titles(res, name_matches)
        end
      end

      # Write the results
      f.write("#{person}:#{total_count}\n")
      puts "#{person} #{total_count}\n\n"
      end_time = Time.now

      # Make sure we do not do > 60 requests per minute
      if req_count == REDDIT_API_LIMIT
        req_count, start = check_api_usage(start, end_time)
      end
    rescue
      puts "Presumably 503 Error on #{person}"
      sleep(2)
      missed.push(person)
    end
  end
  f.close
  missed
end

##############################################
#               GET ARTICLES                 #
# => Used in results. Returns an array of    #
# people who erred. Keeps being called       #
# "recursively" until no more people have    #
# erred. Writes to withArticles.txt          #
# => r - the Reddit API wrapper              #
# => people - the array of people to search  #
##############################################
# TODO -> Breaks order if a person errs! Also breaks their relative ranking!
def get_article(top50)
  faroo_key = File.open('config.yml') { |f| YAML.load(f)['FAROOKEY'] }
  f = File.open('withArticles.txt', 'a')
  missed = []
  position = 1
  db = DB.new
  facebook = FacebookAPI.new
  twitter = TwitterAPI.new
  wikipedia = WikipediaAPI.new
  ranking = 1
  top50.each do |person|
    begin
      search = person.split(':')[0]
      uri = URI.parse(
        URI.encode(
          "http://www.faroo.com/api?q=#{search}&src=news&key=#{faroo_key}"
        )
      )
      res = JSON.parse(Net::HTTP.get(uri))
      # TODO; clean this up, and if there are no results this will break
      name = get_names(search)
      title = ''
      res['results'].each do |a|
        name.each do |n|
          if n.match(a['title'])
            title = a['title'].chomp
            article = a['url'].chomp
            next
          end
        end
        if !title.empty?
          break
        end
      end
      puts "Getting article for #{position}. #{search}"
      position += 1
      information = {}
      information['name'] = search
      information['article_title'] = replace_bad_characters(title)
      information['article_url'] = article
      # Later on, we should search for the ones that don't have values
      # Right now we only search if none of them are populated
      fpage, tpage, wpage = db.get_person_links(search)
      if fpage.nil? && tpage.nil? && wpage.nil?
        fpage = facebook.get_facebook_page(search)
        tpage = twitter.get_twitter_acct(search)
        wpage = wikipedia.get_wikipedia_page(search)
        db.add_person_links(search, fpage, tpage, wpage)
      end
      information['facebook'] = fpage
      information['twitter'] = tpage
      information['wikipedia'] = wpage
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
  f.close
  missed
end

##############################################
#               ADD PEOPLE                   #
# => Adds people from toAdd.txt to           #
# people.txt. Does not add duplicates        #
##############################################
# TODO this is sketchy. Needs to sort people at the end?
def add_people
  f = File.open('toAdd.txt', 'r')
  toadd = []
  f.each_line do |line|
    toadd.push(line)
  end
  f.close
  # Make sure there is a new line on the last entry
  toadd[-1].delete!("\n")
  toadd[-1] += "\n"

  f = File.open('people.txt', 'r')
  people = []
  f.each_line do |line|
    people.push(line)
  end
  f.close
  # need clone so that can do delete()?
  adding = toadd.clone
  # If people doesn't have this person then add them to the people list
  toadd.each do |x|
    if people.include?(x)
      adding.delete(x)
      puts "#{x.strip} is already part of the list!"
    else
      people.push(x)
    end
  end
  # Delete duplicates and sort
  people = people.uniq.sort
  File.open('people.txt', 'w') do |e|
    people.each { |x| if adding.include?(x) then puts "Added #{x}" end; e.write(x) }
  end
end

##############################################
#              DELETE PEOPLE                 #
# => Deletes from people.txt (toDelete.txt)  #
##############################################
# TODO - don't care about case
def delete_people
  del = []
  File.open('toDelete.txt', 'r') do |f|
    f.each_line do |line|
      del.push(line.strip.downcase)
    end
  end
  people = people_list
  # The people who should not be deleted
  updated = []
  people.each do |entry|
    if del.include?(entry.downcase)
      puts "Deleting #{entry}"
      next
    else
      updated.push(entry)
    end
  end
  File.open('people.txt', 'w') do |f|
    updated.each { |x| f.write("#{x}\n") }
  end
end

############################################
#            Boring Utility Stuff          #
############################################

# Returns an authorized Reddit API
def get_reddit_api
  values = []
  %w(REDDITCLIENTID REDDITUSERNAME REDDITPASSWORD REDDITSECRET).each do |x|
    File.open('config.yml') { |f| values.push(YAML.load(f)[x]) }
  end
  id, uname, pword, secret = values
  r = Redd.it(:script, id, secret, uname, pword, user_agent: 'peopole v1.0.0')
  r.authorize!
  puts 'Redd is authenticated!'
  r
end

# Sleeps if we make > REDDIT_API_LIMIT per minute
# Rounds the output because otherwise team members cannot handle the accuracy!
def check_api_usage(start, end_time)
  if (end_time - start) < 60
    puts "\n* WAITING #{((start + 60) - end_time).round(2)} SECONDS *\n\n"
    sleep((start + 60) - end_time)
  end
  # Reset the 'counting' values
  return 0, Time.now
end

def replace_bad_characters(str)
  replace = [['—', '-'], ['–', '-'], ['’', "'"], ['‘', "'"]]
  replace.each { |chars| str.gsub!(chars[0], chars[1]) }
  str
end

# Parses the returned JSON and only increments the count
# for articles that include the person's name in the article title
def count_titles(json, person)
  c = 0
  json.each { |title| person.any? { |m| if m.match(title['title']) then c += 1 end } }
  c
end

# We can add specific rules as methods later (the Dr. Dre case)
def get_names(person)
  # Make sure that there is non alphanumeric after their name
  result = [/#{person}\W/]
  # Deal with the possessive case
  person[-1] == 's' ? result.push(/#{person}'\W/) : result.push(/#{person}'s\W/)
  result
end

# Returns an array (without \n) of all the people we are searching for
def people_list
  people = []
  peeps = File.open('people.txt').read
  peeps.each_line do |line|
    people.push(line.delete!("\n"))
  end
  people
end

# Sort people.txt alphabetically
def sort_people
  sorted = File.readlines('people.txt').sort
  File.open('people.txt', 'w') { |f| sorted.each { |entry| f.write(entry) } }
end

######################
######## MAIN ########
######################
if ARGV[0] == '-p'
  sort_people
elsif ARGV[0] == '-t'
  sort_results
elsif ARGV[0] == '-g'
  results
elsif ARGV[0] == '-a'
  add_people
elsif ARGV[0] == '-d'
  delete_people
elsif ARGV[0] == '-ignore'
  db = DB.new
  db.ignore_person_profile(ARGV[1], ARGV[2])
elsif ARGV[0] == '-force'
  get_article([])
else
  puts "\nUSAGE: run 'ruby judge' with one of the following parameters"
  puts "\t-g (get the results)"
  puts "\t-t (sort the results by # of tweets and get the related article)"
  puts "\t-p (sort people.txt alphabetically)"
  puts "\t-a (add people from toAdd.txt)"
  puts "\t-d (delete people from toDelete.txt)"
end
