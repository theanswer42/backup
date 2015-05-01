require File.join(File.dirname(__FILE__), "test_helper")
require "fileutils"
require "yaml"
require "ostruct"
require "byebug"
require_relative "../lib/database"
require_relative "../lib/bfile"

class TestBFile < MiniTest::Test
  def setup()
    Backup::Database.close()
    @working_dir = File.join(File.dirname(__FILE__), "test_working")
    @fixtures_dir = File.join(File.dirname(__FILE__), "fixtures")
    FileUtils.rm_rf(@working_dir)
    FileUtils.mkdir_p(@working_dir)
  end

  def install_db(name)
    FileUtils.cp(File.join(@fixtures_dir, name), File.join(@working_dir, "backup.db"))
    config = OpenStruct.new()
    config.data_dir = @working_dir
    db = Backup::Database.open("backup", config)
    db
  end
  
  def test_find_by_checksum
    install_db("backup1.db")
    
    config = OpenStruct.new()
    config.data_dir = @working_dir

    now = Time.now

    assert Backup::BFile.find_by_checksum("abcd")
    assert Backup::BFile.find_by_checksum("efgh")
    assert !Backup::BFile.find_by_checksum("efgh1")
  end
  
  def test_create_simple
    config = OpenStruct.new()
    config.data_dir = @working_dir

    Backup::Database.open("backup", config)
    now = Time.now
    Backup::BFile.create(file_id: "1234", hostname: "test", filename: "file1.txt", checksum: "abcd", backed_up_at: now, external_id: "amzn1")

    Backup::BFile.create(file_id: "1235", hostname: "test", filename: "file1.txt", checksum: "efgh", backed_up_at: now, reference_file_id: "host2:3321")

    Backup::Database.close()

    db = SQLite3::Database.new(File.join(@working_dir, "backup.db"))
    db.results_as_hash = true
    
    file1 = db.get_first_row("select * from files where file_id=?", "1234")
    assert_equal "1234", file1["file_id"]
    assert_equal "test", file1["hostname"]
    assert_equal now.to_i, file1["backed_up_at"]
    assert_equal "file1.txt", file1["filename"]
    assert_equal "abcd", file1["checksum"]
    assert_equal "amzn1", file1["external_id"]
    
    file2 = db.get_first_row("select * from files where file_id=?", "1235")
    assert_equal "1235", file2["file_id"]
    assert_equal "test", file2["hostname"]
    assert_equal now.to_i, file2["backed_up_at"]
    assert_equal "file1.txt", file2["filename"]
    assert_equal "efgh", file2["checksum"]
    assert_equal "host2:3321", file2["reference_file_id"]
    
    assert_equal 2, db.get_first_value("select count(*) from files")
  end

  def test_create_validations
    config = OpenStruct.new()
    config.data_dir = @working_dir

    Backup::Database.open("backup", config)

    now = Time.now
    
    assert_raises(Backup::ValidationError) do
      Backup::BFile.create(hostname: "test", filename: "file1.txt", checksum: "abcd", backed_up_at: now, external_id: "amzn1")
    end

    assert_raises(Backup::ValidationError) do
      Backup::BFile.create(file_id: "1234", filename: "file1.txt", checksum: "abcd", backed_up_at: now, external_id: "amzn1")
    end

    assert_raises(Backup::ValidationError) do
      Backup::BFile.create(file_id: "1234", hostname: "test", checksum: "abcd", backed_up_at: now, external_id: "amzn1")
    end

    assert_raises(Backup::ValidationError) do
      Backup::BFile.create(file_id: "1234", hostname: "test", filename: "file1.txt", backed_up_at: now, external_id: "amzn1")
    end

    assert_raises(Backup::ValidationError) do
      Backup::BFile.create(file_id: "1234", hostname: "test", filename: "file1.txt", checksum: "abcd", external_id: "amzn1")
    end
    
    assert_raises(Backup::ValidationError) do
      Backup::BFile.create(file_id: "1234", hostname: "test", filename: "file1.txt", checksum: "abcd", backed_up_at: "1234", external_id: "amzn1")
    end

    assert_raises(Backup::ValidationError) do
      Backup::BFile.create(file_id: "1234", hostname: "test", filename: "file1.txt", checksum: "abcd", backed_up_at: now)
    end

    Backup::BFile.create(file_id: "1234", hostname: "test", filename: "file1.txt", checksum: "abcd", backed_up_at: now, external_id: "amzn1")
    assert_raises(Backup::ValidationError) do
      Backup::BFile.create(file_id: "1234", hostname: "test", filename: "file1.txt", checksum: "abcd", backed_up_at: now, external_id: "amzn1")
    end
  end
  
end
