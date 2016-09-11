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

  def add_ranking(today, name, title, url, rank)
    @db.execute("insert into ranking (name, title, url, day, rank) values (?, ?, ?, ?, ?);",
    [name, title, url, today, rank])
  end

  def get_relative_rank(name, today, yesterday)
    today_rank = @db.execute("select rank from ranking where day = ? and name = ?", today, name)
    yesterday_rank = @db.execute("select rank from ranking where day = ? and name = ?", yesterday, name)
    if yesterday_rank.size > 0
      return yesterday_rank[0] - today_rank
    else
      return "NEW"
    end
  end

  def get_person_today(day, rank)
    return @db.execute("select name, title, url from ranking where day = ? and rank = ?;", day, rank)
  end

end
