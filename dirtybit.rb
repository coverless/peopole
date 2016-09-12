require 'sqlite3'

# class to interface with the sqlite3 db
class DB
  def initialize
    @db = SQLite3::Database.new 'peopole.db'
    @today = get_date(false)
    @yesterday = get_date(true)
  end

  def get_date(is_yesterday)
    date =
      if is_yesterday
        Date.today - 1
      else
        Date.today
      end
    "#{date.year}_#{format_date(date.month)}_#{format_date(date.day)}"
  end

  # Duplicated from judge.rb
  def format_date(date)
    date < 10 ? "0#{date}" : date
  end

  def get_person_links(name)
    @db.execute('select facebook, twitter, wikipedia from people '\
      'where name=(?);', [name])[0]
  end

  # If there was something recorded already it will be overwritten
  # This should just take in a person object?
  def add_person_links(name, f, t, w)
    puts "INSERT #{f} #{t} #{w}"
    @db.execute('update people set facebook=(?), twitter=(?), wikipedia=(?) '\
      'where name=(?);', [f, t, w, name])
  end

  def delete_today
    @db.execute('delete from ranking where day = ?', @today)
  end

  def add_ranking(name, title, url, rank)
    @db.execute('insert into ranking (name, title, url, day, rank) '\
      'values (?, ?, ?, ?, ?);', [name, title, url, @today, rank])
  end

  def get_relative_rank(name)
    today_rank = @db.execute('select rank from ranking '\
      'where day = ? and name = ?;', @today, name)
    yesterday_rank = @db.execute('select rank from ranking '\
      'where day = ? and name = ?;', @yesterday, name)
    return 'NEW', 'green' if yesterday_rank.empty?
    get_rank_and_style(yesterday_rank[0].first - today_rank[0].first)
  end

  def get_rank_and_style(rank)
    return '▬', '' if rank.zero?
    return "▲#{rank}", 'green' if rank > 0
    return "▼#{rank.to_s[1..-1]}", 'red' if rank < 0
  end

  def get_person_today(rank)
    @db.execute('select name, title, url from ranking '\
      'where day = ? and rank = ?;', @today, rank)
  end
end
