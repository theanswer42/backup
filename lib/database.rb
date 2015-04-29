require "sqlite3"
require File.join(File.dirname(__FILE__), "logger")
require File.join(File.dirname(__FILE__), "errors")

module Backup
  class Database
    attr_reader :db
    def initialize(name, config)
      @db = SQLite3::Database.new(File.join(config.data_dir, "#{name}.db"))
      @db.results_as_hash = true
      if !get_first_row("select name from sqlite_master where type='table' and name='versions';")
        init_sql = File.read(File.join(File.dirname(__FILE__), "../sql/#{name}.sql"))
        init_sql << "create table versions(version int(11) not null);\n"
        init_sql << "insert into versions values (#{Time.now.to_i});\n"
        self.execute_batch(init_sql)
      end
    end
    
    def close()
      @db.close()
    end

    def closed?
      @db.closed?
    end

    def commit
      @db.commit if @db.transaction_active?
    end

    def self.open(name, config)
      raise Backup::DatabaseError.new("A Database is already open") if @database
      @database = Backup::Database.new(name, config)
    end
    
    def self.close
      if @database && !@database.closed?
        @database.commit
        @database.close
      end
      @database = nil
    end

    def self.database
      @database
    end
    
    def query(query, values)
      result_set = @db.query(query, values)
      result = []
      result_set.each do |row|
        result << row
      end
      result_set.close

      Backup::Logger.log("query:\nSQL:\n#{query}\nVALUES:\n#{values.inspect}\n\nRESULT:\n#{result.inspect}")
      result
      
    ensure
      result_set.close
    end
    
    def execute_batch(sql)
      result = @db.execute_batch(sql)
      Backup::Logger.log("execute:\nSQL:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end
    
    def execute(sql, *params)
      result = @db.execute(sql, params)
      Backup::Logger.log("execute:\nSQL:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end

    def get_first_row(sql, *params)
      result = @db.get_first_row(sql, params)
      Backup::Logger.log("get_first_row:\nSQL:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end

    def get_first_value(sql)
      result = @db.get_first_value(sql)
      Backup::Logger.log("get_first_value:\nQUERY:\n#{sql}\n\nRESULT:\n#{result.inspect}")
      result
    end
  
  end
end
