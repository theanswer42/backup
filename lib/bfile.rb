require File.join(File.dirname(__FILE__), "database")

module Backup
  class BFile
    
    def self.find_by_checksum(checksum)
      Backup::Database.database.get_first_row("select * from files where checksum=?;", checksum)
    end

    def self.create(attributes)
      # Validations
      [:file_id, :filename, :hostname, :checksum, :backed_up_at].each do |attr|
        raise Backup::ValidationError.new("#{attr.to_s} not set") if attributes[attr].nil? || attributes[attr]==""
      end

      raise Backup::ValidationError.new("backed_up_at must be a time") unless attributes[:backed_up_at].is_a?(Time)

      external_id = attributes[:external_id]||""
      reference_file_id = attributes[:reference_file_id]||""
      raise Backup::ValidationError.new("external_id or reference_file_id must be set") if external_id.empty? && reference_file_id.empty?
      file_id = attributes[:file_id]
      existing_file = Backup::Database.database.get_first_row("select * from files where file_id=?;", file_id)
      raise Backup::ValidationError.new("File already exists") if existing_file
      
      
      result = Backup::Database.database.execute(
        "insert into files(file_id, hostname, filename, checksum, backed_up_at, external_id, reference_file_id) values (?, ?, ?, ?, ?, ?, ?);", [
          file_id,
          attributes[:hostname],
          attributes[:filename],
          attributes[:checksum],
          attributes[:backed_up_at].to_i,
          external_id,
          reference_file_id
        ])
    end

  end
end
