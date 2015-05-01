require File.join(File.dirname(__FILE__), "test_helper")
require "fileutils"
require "yaml"
require "ostruct"
require "byebug"
require_relative "../lib/file_backup.rb"

module DummyBackupFile  
  def backup_file(filename)
    @backed_up_files||={}
    @backed_up_files[filename] = true
  end

  def backed_up_files
    @backed_up_files.keys.sort
  end
end

module DummyProcessList
  def process_list(filename)
    @processed_lists ||= {}
    @processed_lists[filename] = true
  end
  def processed_lists
    @processed_lists.keys.sort
  end
end

module ProcessListFail
  def process_list(filename)
    raise "error"
  end
end

class TestFileBackup < MiniTest::Test
  def setup()
    @working_dir = File.join(File.dirname(__FILE__), "test_working")
    @fixtures_dir = File.join(File.dirname(__FILE__), "fixtures")
    @config_dir = File.join(File.dirname(__FILE__), "config")
    @scanner_dir = File.join(@working_dir, "scanner")
    @backup_dir = File.join(@working_dir, "backup")
    
    FileUtils.rm_rf(@working_dir)
    FileUtils.mkdir_p(@working_dir)
    FileUtils.mkdir_p(File.join(@working_dir, "log"))
    FileUtils.mkdir_p(File.join(@working_dir, "data"))

    FileUtils.mkdir_p(@scanner_dir)
    FileUtils.mkdir_p(@backup_dir)

    FileUtils.rm_rf(@config_dir)
    FileUtils.mkdir_p(@config_dir)
  end

  def generate_default_config(overrides={})
    config = {hostname: "test", gpg_email: "test@backup", base_dir: @working_dir, excludes: ["~$", "doc$"] }.merge(overrides)

    filename = File.join(@config_dir, "scanner.yml")
    cf = File.open(filename, "w")
    cf << config.to_yaml
    cf.close
    filename
  end
  
  def test_process_list
    config_filename = generate_default_config()
    scanner_filename = File.join(@scanner_dir, "list1.list")
    scanner_file1 = File.open(scanner_filename, "w")
    scanner_file1 << "path1  \n  path2\n"
    # scanner_file1 << Dir.glob("locations/location1/**").collect {|f| File.absolute_path(f) }.join("\n")
    scanner_file1.close
    backup = Backup::FileBackup.new(config_filename)
    backup.extend(DummyBackupFile)
    assert_equal 1, Dir.glob(File.join(@scanner_dir, "*.list")).length
    
    backup.send("process_list", scanner_filename)
    assert_equal ["path1", "path2"], backup.backed_up_files
    assert_equal 0, Dir.glob(File.join(@scanner_dir, "*.list")).length
  end

  def test_work_pid_exists
    config_filename = generate_default_config()

    pid_file = File.open(File.join(@working_dir, "backup.pid"), "w")
    pid_file << "1234\n"
    pid_file.close
    
    backup = Backup::FileBackup.new(config_filename)
    backup.extend(DummyBackupFile)

    failed = false
    begin
      backup.work
    rescue Exception => e
      failed = true
    end
    assert failed
  end

  def test_work_processes_list_files
    config_filename = generate_default_config()

    scanner_filename = File.join(@scanner_dir, "list1.list")
    scanner_file1 = File.open(scanner_filename, "w")
    scanner_file1 << "path1\n"

    scanner_filename = File.join(@scanner_dir, "list2.list")
    scanner_file1 = File.open(scanner_filename, "w")
    scanner_file1 << "path1\n"

    scanner_filename = File.join(@scanner_dir, "list3.list")
    scanner_file1 = File.open(scanner_filename, "w")
    scanner_file1 << "path1\n"
    
    scanner_filename = File.join(@scanner_dir, "list3.lock")
    scanner_file1 = File.open(scanner_filename, "w")
    scanner_file1 << "path1\n"
    
    scanner_filename = File.join(@scanner_dir, "list4.txt")
    scanner_file1 = File.open(scanner_filename, "w")
    scanner_file1 << "path1\n"
    
    backup = Backup::FileBackup.new(config_filename)
    backup.extend(DummyProcessList)
    backup.work

    assert_equal ["list1.list", "list2.list"], backup.processed_lists.collect {|n| File.basename(n) }
    
  end

  def test_compute_file_id
    config_filename = generate_default_config()
    backup = Backup::FileBackup.new(config_filename)

    file_id_1 = backup.send("compute_file_id", "file1.txt", "123456")
    assert_equal file_id_1, backup.send("compute_file_id", "file1.txt", "123456")
    assert file_id_1 != backup.send("compute_file_id", "file2.txt", "123456")
    assert file_id_1 != backup.send("compute_file_id", "file1.txt", "1234526")

    config_filename = generate_default_config(hostname: "test2")
    backup = Backup::FileBackup.new(config_filename)
    assert file_id_1 != backup.send("compute_file_id", "file1.txt", "123456")
  end

  def test_compute_checksum
    config_filename = generate_default_config()
    backup = Backup::FileBackup.new(config_filename)

    filename = File.join(File.dirname(__FILE__), "locations", "location1", "file1.txt")
    assert_equal "a940d8aadc02f798331b2d46f1a8ad2c9821783060f4a0810da42bf785855c1c", backup.send("compute_checksum", filename)
    filename = File.join(File.dirname(__FILE__), "locations", "location1", "file2.txt")
    assert_equal "ab1ad6a49c022416008887464b8dc03b523b9e81530cf47d1f6f7712c1b30955", backup.send("compute_checksum", filename)
  end
  
  def test_backup_file
    config_filename = generate_default_config()
    backup = Backup::FileBackup.new(config_filename)

    filename = File.join(File.dirname(__FILE__), "locations", "location1", "file1.txt")
    assert File.exists?(filename)

    backup.send("backup_file", filename)
  end
  
end
