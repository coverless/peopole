# Sorts the file by the most results
# Done in Ruby, because we aren't bad

require 'yaml'

# May not be needed
require 'net/http'
require 'open-uri'
require 'openssl'
require 'json'
# Can be prettier
require "./alchemyapi_ruby/alchemyapi.rb"


# Queries Alchemy and returns the # of articles for each person
# Writes to results.txt
def getResults
  apikey = File.open("config.yml") { |f| YAML.load(f)['ALCHEMYKEY'] }
  alchemyapi = AlchemyAPI.new()
  puts "Created AlchemyAPI"

  # TODO -> MAKE THE MAGIC HAPPEN!

end


# Outputs top results in final.txt by number of tweets
def sortResults
  # Replace numbers like 51,969 with 51969 (so that we can compare them)
  File.open("clean.txt", "w") do |c|
    File.foreach("results.txt") { |line| x = line.gsub(",", ""); c.write(x) }
  end

  # Format date to YYYY-MM-DD
  date = Time.new
  day = date.day.to_s.length == 1 ? "0" + date.day.to_s : date.day.to_s
  month = date.month.to_s.length == 1 ? "0" + date.month.to_s : date.month.to_s

  fname = Dir.pwd + "/logs/#{date.year}-#{month}-#{day}.txt"
  # Obfuscated and unreadable to make it seem that I know hax
  # Writes the sorted results to final.txt
  File.open(fname, "w") do |f|
    File.read("clean.txt")
      .split("\n").sort_by{ |x| both = x.split(":"); -both[1].to_i }  # -both so it is descending
      .first(101).each{ |entry| f.write(entry+"\n") }
  end

  # Push the results to the repo
  # Using this would cause commit errors until we take 'logs/' out of the .gitignore
  # TODO - Need to automate providing uname/pwd
  # system("git add #{fname}")
  # system("git commit -m '#{fname}'")
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
