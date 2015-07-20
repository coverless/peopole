# Manages the people.txt

# Takes toAdd.txt and adds it to people.txt, but not the duplicates!
def addPeople
  puts "Adding people from toAdd.txt"

  f = File.open("toAdd.txt", "r")
  toadd = []
  f.each_line do |line|
    toadd.push(line)
  end
  f.close()

  f = File.open("people.txt", "r")
  people = []
  f.each_line do |line|
    people.push(line)
  end
  f.close()

  # If people doesn't have this person then add them to the people list
  toadd.each { |x| people.include?(x) ? next : people.push(x) }

  # Delete duplicates and sort
  people.uniq!
  people.sort!

  File.open("people.txt", "w") do |f|
    people.each { |x| f.write(x) }
  end

end



##############
#### MAIN ####
##############

addPeople
