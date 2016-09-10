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

  def add_today_column(today)
    rows = @db.execute <<-SQL
      create table if not exists ranking (
        rowid integer primary key
      ) without rowid;
    SQL
    # TODO properly sanitize strings
    begin
      @db.execute("alter table ranking add column #{today}_title varchar(256);")
      @db.execute("alter table ranking add column #{today}_url varchar(256);")
    rescue
      puts "Columns already exist... we are fine"
    end
  end
end
