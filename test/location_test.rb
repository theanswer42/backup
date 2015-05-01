require File.join(File.dirname(__FILE__), "test_helper")

require "fileutils"
require "yaml"
require "ostruct"
require "byebug"
require_relative "../lib/database"
require_relative "../lib/location"

class TestLocation < MiniTest::Unit::TestCase
  def setup()
    Backup::Database.close()
    @working_dir = File.join(File.dirname(__FILE__), "test_working")
    @fixtures_dir = File.join(File.dirname(__FILE__), "fixtures")
    FileUtils.rm_rf(@working_dir)
    FileUtils.mkdir_p(@working_dir)
  end
  
  def install_db(name)
    FileUtils.cp(File.join(@fixtures_dir, name), File.join(@working_dir, "scanner.db"))
    config = OpenStruct.new()
    config.data_dir = @working_dir
    db = Backup::Database.open("scanner", config)
    db
  end
  
  def test_scanner_create_location
    db = install_db("scanner1.db")
    assert !db.db.get_first_row("select * from locations limit 1;")
    Backup::Location.create("1", "/a/b", "enabled", Time.now)
    assert db.db.get_first_row("select * from locations limit 1;")

    # Duplicate location create fails
    failed = false
    begin
      Backup::Location.create("1", "/a/b", "enabled", Time.now)
    rescue Exception => e
      failed = true
    end
    assert failed
  end

  def test_scanner_update_location
    db = install_db("scanner2.db")
    Backup::Location.update('1', status: 'disabled')
    assert_equal 'disabled', db.db.get_first_value("select status from locations where location_id='1'")
    t = Time.now
    Backup::Location.update('2', scanned_at: t)
    assert_equal t.to_i, db.db.get_first_value("select scanned_at from locations where location_id='2'")
  end

  def test_scanner_get_location
    db = install_db("scanner2.db")
    location = Backup::Location.find('1')
    assert_equal 1, location["scanned_at"]
    assert_equal "/a/b", location["location_path"]

    assert !Backup::Location.find('3')
       
  end
end
