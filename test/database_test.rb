require "./test_helper"
require "fileutils"
require "yaml"
require "ostruct"
require_relative "../lib/database"

class TestDatabase < MiniTest::Unit::TestCase
  def setup()
    @working_dir = File.join(File.dirname(__FILE__), "test_working")
    @fixtures_dir = File.join(File.dirname(__FILE__), "fixtures")
    FileUtils.rm_rf(@working_dir)
    FileUtils.mkdir_p(@working_dir)
    Backup::Database.close()
  end

  def test_scanner_db_init
    config = OpenStruct.new()
    config.data_dir = @working_dir

    db = Backup::Database.open("scanner", config)
    db.close
    assert File.exists?(File.join(@working_dir, "scanner.db"))
    db = SQLite3::Database.new(File.join(@working_dir, "scanner.db"))
    t = Time.now.to_i
    assert (t-db.get_first_value("select max(version) from versions")) < 2

    assert_equal "locations", db.get_first_value("select name from sqlite_master where type='table' and name='locations';")
  end

  def test_backup_db_init
    config = OpenStruct.new()
    config.data_dir = @working_dir

    db = Backup::Database.open("backup", config)
    db.close
    assert File.exists?(File.join(@working_dir, "backup.db"))
    db = SQLite3::Database.new(File.join(@working_dir, "backup.db"))
    t = Time.now.to_i
    assert (t-db.get_first_value("select max(version) from versions")) < 2

    assert_equal "files", db.get_first_value("select name from sqlite_master where type='table' and name='files';")
  end

  def install_db(name)
    FileUtils.cp(File.join(@fixtures_dir, name), File.join(@working_dir, "scanner.db"))
    config = OpenStruct.new()
    config.data_dir = @working_dir
    db = Backup::Database.open("scanner", config)
    db
  end
  
  def test_scanner_db_init_existing_db
    db = install_db("scanner1.db")
   
    t = Time.now.to_i

    assert (t-db.db.get_first_value("select max(version) from versions")) > 10

    assert_equal "locations", db.db.get_first_value("select name from sqlite_master where type='table' and name='locations';")
    db.close
  end

  # Need more test coverage here!

  
end
