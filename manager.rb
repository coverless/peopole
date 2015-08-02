# Manages the people.txt
require 'redd'
require 'yaml'
require 'json'


# Takes toAdd.txt and adds it to people.txt, but not the duplicates!
# TODO this is sketchy
# Needs to sort people at the end
def addPeople
  puts "Adding people from toAdd.txt"

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

  # If people doesn't have this person then add them to the people list
  toadd.each { |x| if people.include?(x) then toadd.delete(x); puts "#{x.strip()} is already part of the list!" else people.push(x) end }
  # Delete duplicates and sort
  people.uniq!
  people.sort!
  File.open("people.txt", "w") do |f|
    people.each { |x| if toadd.include?(x) then puts "Added #{x}" end; f.write(x) }
  end
end

# Returns an array (without \n) of all the people we are searching for
# TODO -> this is duplicated from sort.rb
# Used in deletePeople
def getPeople()
  people = []
  peeps = File.open("people.txt").read
  peeps.each_line do |line|
    people.push(line.gsub!("\n", ""))
  end
  # This is ugly
  return people
end

# Makes sure that we are not exceeding 60 requests per minute
# Sleeps if we are going over
# TODO -> duplicated from sort
def checkRequests(start, endTime)
  if ((endTime - start) < 60)
    puts "Waiting #{(start + 60) - endTime} seconds"
    sleep((start + 60) - endTime)
  end
end

# Cleans up people.txt
# Anyone who hasn't been mentioned in 1 month is deleted
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

      # Make sure we do not do > 60 requests per minute
      if reqCount == 60
        # checkRequests will sleep if need be
        checkRequests(start, endTime)
        reqCount = 0
        start = Time.now
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

# Reads from the text file of names to delete
def deletePeople
  del = []
  File.open("toDelete.txt", "r") do |f|
    f.each_line do |line|
      del.push(line.strip)
    end
  end
  people = getPeople()
  # The people who should not be deleted
  updated = []
  people.each do |entry|
    if del.include? (entry)
      # They should be deleted
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

# Returns an authorized Reddit API
# TODO -> this is duplicated from sort.rb
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


##############
#### MAIN ####
##############
if ARGV[0] == "-a"
  addPeople
elsif ARGV[0] == "-c"
  cleanUpPeople
elsif ARGV[0] == "-d"
  deletePeople
else
  puts "\nUSAGE: run 'ruby manager' with one of the following parameters"
  puts "\t-a (add people from toAdd.txt)"
  puts "\t-c (cleanup people who are never mentioned)"
  puts "\t-d (delete people from toDelete.txt)"
end
