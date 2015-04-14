require "sqlite3"
require File.join(File.dirname(__FILE__), "logger")

module Backup
  class Database
    attr_reader :db
    def initialize(name, config)
      db_filename = File.join(config["data_dir"], "#{name}.db")
      @db = SQLite3::Database.new(db_filename)
      migrate()
    end

    def close()
      db.close()
    end

    # API for locations
    # This could potentially be moved in another layer on top of the db layer, but right now
    # no need to.
    def create_location(location_id, location, status, scanned_at)
      result = query("insert into locations(location_id, location, status, scanned_at values (?, ?, ?, ?);", [location_id, location, status, scanned_at])
    end

    def update_location(location_id, update)
      values = []
      sql = []
      update.each do |key, value|
        sql << "#{key} = ?"
        values = value
      end
      values << location_id
      result = query("update locations set #{sql.join(',')} where location_id = ?", values)
    end

    def get_location(location_id)
      result = get_first_result("select location_id, location, status, scanned_at from locations where location_id='#{location_id}';")
      return {location_id: result[0], location: result[1], status: result[2], scanned_at: result[3])
    end
    
    private
    
    def current_db_version()
      if get_first_row("select name from sqlite_master where type='table' and name='versions';")
        return -1
      else
        version = get_first_value("select max(version) from versions;")
        if version
          return version.to_i
        else
          return -1
        end
      end
    end

    def execute(sql)
      result = db.execute(sql)
      Backup::Logger.log("execute:\nSQL:\n#{migration_filename}\nQUERY:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end

    def get_first_result(sql)
      result = db.get_first_result(sql)
      Backup::Logger.log("get_first_result:\nSQL:\n#{migration_filename}\nQUERY:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end

    def get_first_value(sql)
      result = db.get_first_value(sql)
      Backup::Logger.log("get_first_value:\nSQL:\n#{migration_filename}\nQUERY:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end

    
    def apply_migrations(current_version)
      if current_version < 0
        execute("create table version(version int(11) not null);")
      end
      migrations_dir = File.join(File.dirname(__FILE__), "../sql/#{name}")
      Dir.glob(File.join(migrations_dir, "**", "*.sql")).sort.each do |migration_filename|
        version = File.basename(migration_filename, File.extname(migration_filename)).to_i
        next if version <= current_version
        sql = File.read(migration_filename)
        sql << "\ninsert into versions values(#{version});"
        execute(sql)
      end
      
    end
    
    def migrate()
      current_version = current_db_version()
      apply_migrations(current_version)
    end
    
  end
end
