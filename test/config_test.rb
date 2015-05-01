require File.join(File.dirname(__FILE__), "test_helper")
require "fileutils"
require "yaml"
require_relative "../lib/config"

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
    yconfig = {hostname: "test", gpg_email: "backup@test.com", locations: [absolute_location, "./locations/location2"],  base_dir: @working_dir, excludes: ["~$", "doc$"] }
    filename = write_config("resolve_locations", yconfig)
    config = Backup::Config.generate_config(filename)
    assert_equal 1, config.locations.length
    assert_equal absolute_location, config.locations.first

    assert_equal 2, config.excludes.length
    assert config.excludes.detect {|e| "a_backup.txt~".match(e) }
    assert config.excludes.detect {|e| "a_word_doc.doc".match(e) }
        
    assert config.base_dir
    assert config.scanner_dir
    assert config.data_dir
    assert config.scanner_pid_file
    assert config.backup_pid_file
    assert config.log_dir
    assert config.hostname
    assert config.gpg_email
  end

  def test_requires_hostname_and_gpg_email
    yconfig = {gpg_email: "backup@test.com", locations: [],  base_dir: @working_dir, excludes: ["~$", "doc$"] }
    filename = write_config("config1", yconfig)
    failed = false
    begin
      config = Backup::Config.generate_config(filename)
    rescue Backup::ConfigError
      failed = true
    end
    assert failed

    yconfig = {hostname: "test", locations: [],  base_dir: @working_dir, excludes: ["~$", "doc$"] }
    filename = write_config("config2", yconfig)
    failed = false
    begin
      config = Backup::Config.generate_config(filename)
    rescue Backup::ConfigError
      failed = true
    end
    assert failed

  end
end
