require "sqlite3"
require File.join(File.dirname(__FILE__), "logger")

# TODO: remove migrations, instead just one "init" method and sql file
# Tests for init
# 


module Backup
  class Database
    attr_reader :db, :db_name
    def initialize(name, config)
      @db_name = name
      @db = SQLite3::Database.new(File.join(config.data_dir, "#{name}.db"))
      @db.results_as_hash = true
      db_init()
    end

    def close()
      db.close()
    end

    # API for locations
    # This should be moved in another layer on top of the db layer, but right now
    # no need to.
    def create_location(location_id, location, status, scanned_at)
      result = query("insert into locations(location_id, location_path, status, scanned_at) values (?, ?, ?, ?);", [location_id, location, status, scanned_at.to_i])
    end

    def update_location(location_id, update)
      values = []
      sql = []
      update.each do |key, value|
        sql << "#{key} = ?"
        values << (key.to_s == "scanned_at" ? value.to_i : value)
      end
      values << location_id
      result = query("update locations set #{sql.join(',')} where location_id = ?", values)
    end

    def get_location(location_id)
      get_first_result("select * from locations where location_id=?;", location_id)
    end
    
    private

    def query(query, values)
      result_set = db.query(query, values)
      result = []
      result_set.each do |row|
        result << row
      end
      result_set.close

      Backup::Logger.log("query:\nSQL:\n#{query}\nVALUES:\n#{values.inspect}\n\nRESULT:\n#{result.inspect}")
      result
    end
    
    def db_init
      if !get_first_row("select name from sqlite_master where type='table' and name='versions';")
        init_sql = File.read(File.join(File.dirname(__FILE__), "../sql/#{self.db_name}.sql"))
        init_sql << "create table versions(version int(11) not null);\n"
        init_sql << "insert into versions values (#{Time.now.to_i});\n"
        execute_batch(init_sql);
      end
    end

    def execute_batch(sql)
      result = db.execute_batch(sql)
      Backup::Logger.log("execute:\nSQL:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end
    
    def execute(sql)
      result = db.execute(sql)
      Backup::Logger.log("execute:\nSQL:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end

    def get_first_row(sql)
      result = db.get_first_row(sql)
      Backup::Logger.log("get_first_result:\nSQL:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end

    def get_first_value(sql)
      result = db.get_first_value(sql)
      Backup::Logger.log("get_first_value:\nQUERY:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end
  
  end
end
