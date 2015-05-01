require File.join(File.dirname(__FILE__), "test_helper")

require "fileutils"
require_relative "../lib/logger"

class TestLogger < MiniTest::Unit::TestCase
  def setup
    @logdir = "./log"
    FileUtils.rm_rf(@logdir)
    FileUtils.mkdir_p(@logdir)
  end

  def teardown
    FileUtils.rm_rf(@logdir)
  end

  def test_create_log_file
    logger = Backup::Logger.new("test", @logdir)
    logger.close
    assert_equal 1, Dir.glob("./log/*").length
  end

  def test_log
    logger = Backup::Logger.new("test", @logdir)
    logger.log("test text")
    logger.close
    logfile = Dir.glob("./log/*").first
    log_text = File.read(logfile)
    assert_equal "test text", log_text.strip
  end

  def test_class_log
    logger = Backup::Logger.new("test", @logdir)
    Backup::Logger.log("test text")
    logger.close
    logfile = Dir.glob("./log/*").first
    log_text = File.read(logfile)
    assert_equal "test text", log_text.strip
  end

  def test_log_line
    logger = Backup::Logger.new("test", @logdir)
    Backup::Logger.log_line("test text")
    logger.close
    logfile = Dir.glob("./log/*").first
    log_text = File.read(logfile).strip.split(" | ")
    assert_equal 2, log_text.length
    assert_equal "test text", log_text.last.strip
  end
  
end
