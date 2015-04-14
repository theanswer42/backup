require File.join(File.dirname(__FILE__), "backup/config")
require 'digest'


class FileScanner
  attr_reader :config, :logger, :database
  def initialize()
    @config = read_config()
    @logger = Backup::Logger.new("scanner", config["log_dir"])
    @database = Backup::Database.new("scanner", config["data_dir"])
  ensure
    @logger.close() if @logger
    @database.close() if @database
  end

  def read_config()
    config_filename = ARGV[0]
    if !config_filename || config_filename.empty?
      puts "config-filename not provided."
      puts "usage: 'scanner.rb config-filename'"
      exit 1
    end
    config = Backup::Config.new(config_filename)
  end
  
  def check_pid
    if File.exists?(config["pid_file"])
      @pid_exists = true
      raise "Another scanner process is running: #{File.read(config['pid_file'])}"
    end
    pid = File.open(options.pid, "w")
    pid << "#{Process.pid}\n"
    pid.close
    return true
  end

  def release_pid
    if !@pid_exists
      FileUtils.rm_f(options.pid)
    end
  end

  def scan
    check_pid

    clear_working_dir
    
    config["locations"].each do |location|
      scan_location(location)
    end
    
  ensure
    release_pid
    logger.close
    database.close
  end

  def clear_working_dir
    FileUtils.rm_rf(config["working_dir"])
    FileUtils.mkdir_p(config["working_dir"])
    FileUtils.mkdir_p(config["scanner_dir"])
  end

  def exclude_file(path)
    config["excludes"].detect {|r| path.match(r) }
  end
  
  def scan_location(location)
    location_id = Digest::SHA256.hexdigest(location)
    working_dir = config["working_dir"]
    location_list_file = File.join(working_dir, location_id)
    location_lock_file = File.join(working_dir, "#{location_id}.lock")
    
    if File.exists?(location_list_file)
      logger.log_line("location: #{location} still not processed. Skipping.")
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
    FileUtils.rm(location_lock_file)
  end

end

f = FileScanner.new
f.scan

