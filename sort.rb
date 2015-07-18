# Sorts the file by the most results
# Done in Ruby, because we aren't bad

require 'yaml'

# May not be needed
require 'net/http'
require 'open-uri'
require 'json'
# Can be prettier

# Writes to results.txt
def getResults
  f = File.open("results.txt", "w")
  people = []
  peeps = File.open("people.txt").read
  peeps.each_line do |line|
    line.gsub!(" ", "%20")
    # May not need to sub out this new line
    people.push(line.gsub!("\n", ""))
  end

  for person in people do
    counter = 0 # This isn't needed
    uri = "http://www.reddit.com/r/all/search.json?q=%22#{person}%22&limit=100&restrict_sr=&sort=new&t=day"
    buffer = open(uri).read
    res = JSON.parse(buffer)
    counter = res["data"]["children"].count
    # If there is a second page

    # repeat = 1
    # while counter == (repeat * 100)
    if counter > 99
      aft = res["data"]["children"][99]["data"]["name"]
      uri = "http://www.reddit.com/r/all/search.json?q=%22#{person}%22&limit=100&after=#{aft}&restrict_sr=&sort=new&t=day"
      res = JSON.parse(open(uri).read)
      counter = counter + res["data"]["children"].count
      # repeat = repeat + 1
    end
      # Write the results
      f.write("#{person.gsub!("%20", " ")}:#{counter}\n")
      puts "#{person}\n"
      # if counter == 0
      #   sleep(1)
      # end
  end

end

# Returns an array of all the people we are searching for
# TODO -> get rid of the spacing in this method?
# For use in getResults
def getPeople
  people = []
  text = File.open("people.txt").read
  text.each_line do |line|
    people.push(line)
  end
  # Might be implicitly returned...
  people
end



# Sorts the results by # of hits
# Uploads both news link file and the daily results file to the repo
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
  newsLinkFile = "newsLink.txt"
  # Obfuscated and unreadable to make it seem that I know hax
  # Writes the sorted results to final.txt
  File.open(resultsFile, "w") do |f|
    File.read("clean.txt")
      .split("\n").sort_by{ |x| both = x.split(":"); -both[1].to_i }  # -both so it is descending
      .first(101).each{ |entry| f.write(entry+"\n") }
  end

  # Push the results to the repo
  # Using this would cause commit errors until we take 'logs/' out of the .gitignore
  # TODO - Need to automate providing uname/pwd
  # system("git add #{resultsFile} #{newsLinkFile}")
  # system("git commit -m '#{resultsFile} #{newsLinkFile}'")
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
  puts "\t-t (sort the results by # of tweets)"
  puts "\t-p (sort people.txt alphabetically)"
  puts "\t-g (get the results)"
end
