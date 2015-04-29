require "./test_helper"
require "fileutils"
require "yaml"
require "ostruct"
require "byebug"
require_relative "../backup/file_scanner.rb"

module DummyBackupFile
  def initialize(config_filename)
    @backed_up_files = {}
    super
  end
  
  def backup_file(filename)
    @backed_up_files[filename] = true
  end

  def backed_up_files
    @backed_up_files.keys.sort
  end
end

class TestFileBackup < MiniTest::Test
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

  def test_process_list
    
  end
   
  
end
