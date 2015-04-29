require File.join(File.dirname(__FILE__), "database")
module Backup
  class Location
    def self.create(location_id, location, status, scanned_at)
      result = Backup::Database.database.execute("insert into locations(location_id, location_path, status, scanned_at) values (?, ?, ?, ?);", [location_id, location, status, scanned_at.to_i])
    end
    
    def self.update(location_id, update)
      values = []
      sql = []
      update.each do |key, value|
        sql << "#{key} = ?"
        values << (key.to_s == "scanned_at" ? value.to_i : value)
      end
      values << location_id
      result = Backup::Database.database.execute("update locations set #{sql.join(',')} where location_id = ?", values)
    end
    
    def self.find(location_id)
      Backup::Database.database.get_first_row("select * from locations where location_id=?;", location_id)
    end
    
  end
end
