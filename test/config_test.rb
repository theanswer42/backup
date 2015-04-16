require "./test_helper"
require "fileutils"
require "yaml"
require_relative "../backup/config"

class TestConfig < MiniTest::Unit::TestCase
  def setup
    @config_dir = File.join(File.dirname(__FILE__), "config")
    @working_dir = File.join(File.dirname(__FILE__), "test_working")
    FileUtils.rm_rf(@config_dir)
    FileUtils.mkdir_p(@config_dir)
    FileUtils.rm_rf(@working_dir)
    FileUtils.mkdir_p(@working_dir)
  end

  def write_config(name, config)
    filename = File.join(@config_dir, "#{name}.yml")
    c = File.open(filename, "w")
    c << config.to_yaml
    c.close
    filename
  end
  
  def test_resolve_locations
    absolute_location = File.expand_path(File.join(File.dirname(__FILE__), "locations", "location1"))
    yconfig = {locations: [absolute_location, "./locations/location2"],  base_dir: @working_dir, excludes: ["~$", "doc$"] }
    filename = write_config("resolve_locations", yconfig)
    config = Backup::Config.generate_config(filename)
    assert_equal 1, config.locations.length
    assert_equal absolute_location, config.locations.first

    assert_equal 2, config.excludes.length
    assert config.excludes.detect {|e| "a_backup.txt~".match(e) }
    assert config.excludes.detect {|e| "a_word_doc.doc".match(e) }
        
    assert config.base_dir
    assert config.working_dir
    assert config.scanner_dir
    assert config.data_dir
    assert config.pid_file
    assert config.log_dir
  end
end
