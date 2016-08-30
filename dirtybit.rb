require 'sqlite3'

class DB
  def initialize
    @db = SQLite3::Database.new "peopole.db"
  end

  def get_person_links(name)
    return @db.execute("select facebook, twitter, wikipedia from people where name=(?);", [name])[0]
  end

  # If there was something recorded already it will be overwritten
  # This should just take in a person object?
  def add_person_links(name, f, t, w)
    puts "INSERT #{f} #{t} #{w}"
    @db.execute("update people set facebook=(?), twitter=(?), wikipedia=(?) where name=(?)", [f, t, w, name])
  end
end
