require 'sqlite3'
class DB
  def self.db
    return @db if @db
    @db = SQLite3::Database.new "database.db"
    @db
  end
  
  def self.start
    self.db.execute <<-SQL
      create table IF NOT EXISTS mappings (
        username varchar(255),
        domain varchar(255)
      );
    SQL
  end
end
DB.start