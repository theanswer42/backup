require "./test_helper"
require "fileutils"
require "yaml"
require "ostruct"
require_relative "../backup/database"

class TestDatabase < MiniTest::Unit::TestCase
  def setup()
    @working_dir = File.join(File.dirname(__FILE__), "test_working")
    @fixtures_dir = File.join(File.dirname(__FILE__), "fixtures")
    FileUtils.rm_rf(@working_dir)
    FileUtils.mkdir_p(@working_dir)
  end

  def test_scanner_db_init
    config = OpenStruct.new()
    config.data_dir = @working_dir

    db = Backup::Database.new("scanner", config)
    db.close
    assert File.exists?(File.join(@working_dir, "scanner.db"))
    db = SQLite3::Database.new(File.join(@working_dir, "scanner.db"))
    t = Time.now.to_i
    assert (t-db.get_first_value("select max(version) from versions")) < 2

    assert_equal "locations", db.get_first_value("select name from sqlite_master where type='table' and name='locations';")
  end

  def install_db(name)
    FileUtils.cp(File.join(@fixtures_dir, name), File.join(@working_dir, "scanner.db"))
    config = OpenStruct.new()
    config.data_dir = @working_dir
    db = Backup::Database.new("scanner", config)
    db
  end
  
  def test_scanner_db_init_existing_db
    db = install_db("scanner1.db")
   
    t = Time.now.to_i

    assert (t-db.db.get_first_value("select max(version) from versions")) > 10

    assert_equal "locations", db.db.get_first_value("select name from sqlite_master where type='table' and name='locations';")
    db.close
  end

  def test_scanner_create_location
    db = install_db("scanner1.db")
    assert !db.db.get_first_row("select * from locations limit 1;")
    db.create_location("1", "/a/b", "enabled", Time.now)
    assert db.db.get_first_row("select * from locations limit 1;")

    # Duplicate location create fails
    failed = false
    begin
      db.create_location("1", "/a/b", "enabled", Time.now)
    rescue Exception => e
      failed = true
    end
    assert failed
  end

  def test_scanner_update_location
    db = install_db("scanner2.db")
    db.update_location('1', status: 'disabled')
    assert_equal 'disabled', db.db.get_first_value("select status from locations where location_id='1'")
    t = Time.now
    db.update_location('2', scanned_at: t)
    assert_equal t.to_i, db.db.get_first_value("select scanned_at from locations where location_id='2'")
  end

  def test_scanner_get_location
    db = install_db("scanner2.db")
    location = db.get_location('1')
    assert_equal 1, location["scanned_at"]
    assert_equal "/a/b", location["location_path"]

    assert !db.get_location('3')
       
  end
end
