# Sorts the file by the most results
# Done in Ruby, because we aren't bad

require 'json'

# Outputs top results in final.txt by number of tweets
def sortResults
  # Replace numbers like 51,969 with 51969 (so that we can compare them)
  File.open("clean.txt", "w") do |c|
    File.foreach("results.txt") { |line| x = line.gsub(",", ""); c.write(x) }
  end

  date = Time.new
  day = date.day.to_s
  month = date.month.to_s
  if day.length == 1
    then day = "0" + day
  end
  if month.length == 1
    then month = "0" + month
  end
  fname = Dir.pwd + "/logs/#{date.year}-#{month}-#{day}.txt"
  # Obfuscated and unreadable to make it seem that I know hax
  # Writes the sorted results to final.txt
  File.open(fname, "w") do |f|
    File.read("clean.txt")
      .split("\n").sort_by{ |x| both = x.split(":"); -both[1].to_i }  # -both so it is descending
      .first(101).each{ |entry| f.write(entry+"\n") }
  end
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
else
  puts "\nUSAGE: run 'ruby sort' with one of the following parameters"
  puts "\t-t (sort the results by # of tweets)"
  puts "\t-p (sort people.txt alphabetically)"
end
