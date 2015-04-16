require "./test_helper"
require "fileutils"
require "yaml"
require "ostruct"
require "byebug"
require_relative "../backup/file_scanner.rb"

class TestFileScanner < MiniTest::Test
  def setup()
    @working_dir = File.join(File.dirname(__FILE__), "test_working")
    @fixtures_dir = File.join(File.dirname(__FILE__), "fixtures")
    @config_dir = File.join(File.dirname(__FILE__), "config")
    
    FileUtils.rm_rf(@working_dir)
    FileUtils.mkdir_p(@working_dir)
    FileUtils.mkdir_p(File.join(@working_dir, "log"))
    FileUtils.mkdir_p(File.join(@working_dir, "data"))
    # FileUtils.mkdir_p(File.join(@working_dir, "run"))
    # FileUtils.mkdir_p(File.join(@working_dir, "run"))
    

    FileUtils.rm_rf(@config_dir)
    FileUtils.mkdir_p(@config_dir)
  end

  def install_db(name)
    FileUtils.cp(File.join(@fixtures_dir, name), File.join(@working_dir, "scanner.db"))
    config = OpenStruct.new()
    config.data_dir = @working_dir
    db = Backup::Database.new("scanner", config)
    db
  end

  def write_config(name, config)
    filename = File.join(@config_dir, "#{name}.yml")
    c = File.open(filename, "w")
    c << config.to_yaml
    c.close
    filename
  end
  
  def test_scanner_pid_check
    absolute_location = File.expand_path(File.join(File.dirname(__FILE__), "locations", "location1"))
    yconfig = {locations: [absolute_location],  base_dir: @working_dir, excludes: ["~$", "doc$"] }
    filename = write_config("scanner", yconfig)
    
    pidfile = File.open(File.join(@working_dir, "scanner.pid"), "w")
    pidfile << "#{Process.pid}\n"
    pidfile.close
    
    f = FileScanner.new(File.join(@config_dir, "scanner.yml"))
    failed = false
    begin
      f.scan
    rescue Exception => e
      failed = true
    end
    assert failed
    assert !File.exists?(File.join(@working_dir, "scanner"))
  end

  def test_scanner_no_locations
    yconfig = {locations: [],  base_dir: @working_dir, excludes: ["~$", "doc$"] }
    filename = write_config("scanner", yconfig)
    
    f = FileScanner.new(File.join(@config_dir, "scanner.yml"))
    f.scan
    
    assert File.exists?(File.join(@working_dir, "scanner"))
    assert !File.exists?(File.join(@working_dir, "scanner.pid"))
  end

  def test_scanner_no_file_list
    absolute_location = File.expand_path(File.join(File.dirname(__FILE__), "locations", "location1"))
    yconfig = {locations: [absolute_location],  base_dir: @working_dir, excludes: ["~$", "doc$"] }
    filename = write_config("scanner", yconfig)

    scan_time = Time.now.to_i
    f = FileScanner.new(File.join(@config_dir, "scanner.yml"))
    f.scan
    
    assert File.exists?(File.join(@working_dir, "scanner"))
    assert !File.exists?(File.join(@working_dir, "scanner.pid"))

    location_lists = Dir.glob(File.join(@working_dir, "scanner", "*"))
    assert_equal 1, location_lists.length

    location_file = location_lists.first
    files = File.read(location_file).split("\n")
    assert_equal ["file1.txt", "file2.txt"], files.collect {|f| File.basename(f) }.sort

    db = SQLite3::Database.new(File.join(@working_dir, "data", "scanner.db"))
    assert_equal 1, db.get_first_value("select count(*) from locations")
    assert (scan_time - db.get_first_value("select scanned_at from locations")) < 5
  end

  def test_scanner_file_list_exists
    absolute_location = File.expand_path(File.join(File.dirname(__FILE__), "locations", "location1"))
    yconfig = {locations: [absolute_location],  base_dir: @working_dir, excludes: ["~$", "doc$"] }
    filename = write_config("scanner", yconfig)

    location_id = Digest::SHA256.hexdigest(absolute_location)
        
    FileUtils.mkdir_p(File.join(@working_dir, "scanner"))
    older_list = File.open(File.join(@working_dir, "scanner", location_id), "w")
    older_list << "something"
    older_list.close
    
    f = FileScanner.new(File.join(@config_dir, "scanner.yml"))
    f.scan

    assert !File.exists?(File.join(@working_dir, "scanner.pid"))
    
    location_lists = Dir.glob(File.join(@working_dir, "scanner", "*"))
    assert_equal 1, location_lists.length
    location_file = location_lists.first
    assert_equal "something", File.read(location_file)
  end

  def test_rescan_updates_scanned_at
    absolute_location = File.expand_path(File.join(File.dirname(__FILE__), "locations", "location1"))
    yconfig = {locations: [absolute_location],  base_dir: @working_dir, excludes: ["~$", "doc$"] }
    filename = write_config("scanner", yconfig)

    location_id = Digest::SHA256.hexdigest(absolute_location)
    config = OpenStruct.new()
    config.data_dir = File.join(@working_dir, "data")
    database = Backup::Database.new("scanner", config)
    other_scan_time = Time.now-60
    database.create_location(location_id, absolute_location, "enabled", other_scan_time)
    database.create_location("2", "/a/b", "enabled", other_scan_time)
    database.close
    
    scan_time = Time.now.to_i
    f = FileScanner.new(File.join(@config_dir, "scanner.yml"))
    f.scan
    
    assert File.exists?(File.join(@working_dir, "scanner"))
    assert !File.exists?(File.join(@working_dir, "scanner.pid"))

    location_lists = Dir.glob(File.join(@working_dir, "scanner", "*"))
    assert_equal 1, location_lists.length

    location_file = location_lists.first
    files = File.read(location_file).split("\n")
    assert_equal ["file1.txt", "file2.txt"], files.collect {|f| File.basename(f) }.sort

    db = SQLite3::Database.new(File.join(@working_dir, "data", "scanner.db"))
    assert_equal 2, db.get_first_value("select count(*) from locations")
    assert (scan_time - db.get_first_value("select scanned_at from locations where location_id=?", location_id)) < 5
    assert_equal other_scan_time.to_i, db.get_first_value("select scanned_at from locations where location_id=?", "2")
    
  end


  
end

