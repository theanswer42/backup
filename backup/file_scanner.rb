require File.join(File.dirname(__FILE__), "config")
require File.join(File.dirname(__FILE__), "database")
require 'digest'

class FileScanner
  attr_reader :config, :logger, :database
  def initialize(config_filename)
    @config = read_config(config_filename)
    @logger = Backup::Logger.new("scanner", config.log_dir)
    @database = Backup::Database.new("scanner", config)
  rescue Exception => e
    @logger.close() if @logger
    @database.close() if @database
  end

  def read_config(config_filename)
    if !config_filename || config_filename.empty?
      puts "config-filename not provided."
      puts "usage: 'scanner.rb config-filename'"
      exit 1
    end
    config = Backup::Config.generate_config(config_filename)
  end
  
  def check_pid
    if File.exists?(config.pid_file)
      @pid_exists = true
      Backup::Logger.log_line("Another scanner process is running: #{File.read(config['pid_file'])}")
      raise "Another scanner process is running: #{File.read(config['pid_file'])}"
    end
    pid = File.open(config.pid_file, "w")
    pid << "#{Process.pid}\n"
    pid.close
    return true
  end

  def release_pid
    if !@pid_exists
      FileUtils.rm_f(config.pid_file)
    end
  end

  def scan
    check_pid

    setup_working_dir
    
    config.locations.each do |location|
      scan_location(location)
    end
    
  ensure
    release_pid
    logger.close
    database.close
  end

  def setup_working_dir
    FileUtils.mkdir_p(config.scanner_dir)
  end

  def exclude_file(path)
    config.excludes.detect {|r| path.match(r) }
  end
  
  def scan_location(location)
    location_id = Digest::SHA256.hexdigest(location)
    working_dir = config.scanner_dir
    location_list_file = File.join(working_dir, location_id)
    location_lock_file = File.join(working_dir, "#{location_id}.lock")
    
    if File.exists?(location_list_file)
      Backup::Logger.log_line("location: #{location} still not processed. Skipping.")
      return
    end

    lock = File.open(location_lock_file, "w")
    lock.close

    list = File.open(location_list_file, "w")

    if(File.file?(location) && !exclude_file(location))
      list << "#{location}\n"
    elsif(File.directory?(location))
      Dir.glob(File.join(location, "**", "*")).each do |filename|
        list << "#{filename}\n" if(File.file?(filename) && !exclude_file(location))
      end
    end
    
    list.close
    if(!database.get_location(location_id))
      database.create_location(location_id, location, "enabled", Time.now)
    else
      database.update_location(location_id, scanned_at: Time.now)
    end
  rescue Exception => e
    Backup::Logger.log("FileScanner.scan_location, exception #{e.message}\n#{e.backtrace.join("\n")}\n")
    FileUtils.rm_f(location_list_file)
  ensure
    FileUtils.rm_f(location_lock_file)
  end

end
