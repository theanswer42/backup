require "ostruct"
require "fileutils"
require "digest"

require File.join(File.dirname(__FILE__), "config")
require File.join(File.dirname(__FILE__), "database")

module Backup
  class FileBackup
    attr_reader :config, :logger, :database
    def initialize(config_filename)
      @config = read_config(config_filename)
      @logger = Backup::Logger.new("backup", config.log_dir)
      @database = Backup::Database.new("backup", config)
    rescue Exception => e
      @logger.close() if @logger
      @database.close() if @database
    end

    def work()
      check_pid
      
      unless File.exists?(config.scanner_dir)
        Backup::Logger.log_line("No scanner directory found. Exiting.")
        return 
      end

      FileUtils.rm_rf(config.backup_dir)
      FileUtils.mkdir_p(config.backup_dir)
      
      Dir.glob(File.join(config.scanner_dir, "*.list")).each do |list_filename|
        location_id = File.basename(list_filename, ".list")
        if File.exists?(File.join(config.scanner_dir, "#{location_id}.lock"))
          Backup::Logger.log_line("List file locked: #{File.basename(list_filename)}. Skipping.")
          next
        end
        process_list(list_filename)
      end

    ensure
      release_pid
      logger.close
      database.close
    end

    private
    
    def process_list(filename)
      IO.foreach(filename, "\n") do |line|
        name = line.strip
        backup_file(name)
      end
      FileUtils.rm(filename)
    end

    def backup_file(filename)
      unless File.exists?(filename)
        Backup::Logger.log_line("File missing: #{filename}. Skipping.")
        return
      end
      hostname = config.hostname
      FileUtils.cp(filename, config.backup_dir)
      working_filename = File.join(config.backup_dir, File.basename(filename))
      
      checksum = compute_checksum(working_filename)
      file_id = compute_file_id(filename, checksum)

      if reference_file = database.file_exists?(checksum)
        # Only do this if its not the same file
        unless file_id == reference_file.file_id
          database.insert_file(file_id: file_id, filename: filename, checksum: checksum, reference_file_id: "#{reference_file.hostname}:#{reference_file.file_id}")
        end
      else
        # Encrypt
        run_command("gpg --output \"#{working_filename}.gpg\" --encrypt --recipient \"#{config.gpg_email}\" \"#{working_filename}\"")
        
        # Upload
        external_id = Backup::AmazonUploader.upload_file(file_id, "#{working_filename}.gpg")

        # Insert into db
        database.insert_file(file_id: file_id, filename: filename, checksum: checksum, external_id: external_id)
        
      end
      
    rescue Exception => e
      log_exception(e)
    ensure
      FileUtils.rm_f(working_filename)
      FileUtils.rm_f("#{working_filename}.gpg")
    end
    
    
    private
    def run_command(command)
      command = "#{command} 2>&1"
      output = status = nil
      begin
        output = `#{command}`
        status = $?.success?
      rescue Exception => e
        output = e.inspect
        status = false
      end
      Backup::Logger.log_command(command, output)
      if !status
        puts command
        puts output
        raise "command failed"
      end
      return output
    end

    
    def compute_file_id(filename, checksum)
      file_id = Digest::SHA256.hexdigest("#{config.hostname}:#{filename}:#{checksum}")
    end
    
    def compute_checksum(filename)
      File.open(path, 'rb') do |io|
        digest = Digest::SHA256.new
        buffer = ""
        digest.update(buffer) while io.read(4096, buffer)
        digest
      end.to_s
    end

    
    def check_pid
      if File.exists?(config.backup_pid_file)
        @pid_exists = File.read(config.backup_pid_file)
        Backup::Logger.log_line("Another scanner process is running: #{@pid_exists}")
        raise "Another scanner process is running: #{@pid_exists)}"
      end
      pid = File.open(config.backup_pid_file, "w")
      pid << "#{Process.pid}\n"
      pid.close
      return true
    end

    def release_pid
      if !@pid_exists
        FileUtils.rm_f(config.backup_pid_file)
      end
    end
    
    def read_config(config_filename)
      if !config_filename || config_filename.empty?
        puts "config-filename not provided."
        puts "usage: 'backup.rb config-filename'"
        exit 1
      end
      config = Backup::Config.generate_config(config_filename)
    end

    
  end
end
