require 'yaml'
require 'ostruct'
require File.join(File.dirname(__FILE__), "logger")

module Backup
  module Config
    def self.generate_config(config_filename)
      config = YAML.load_file(config_filename)
      config = OpenStruct.new(config)

      locations = (config.locations||[]).collect do |path|
        if path.match(/^\//)
          path = File.expand_path(path)
        else
          Backup::Logger.log_line("Config: Ignoring non-absolute path: #{path}")
          path = nil
        end
        path
      end
      config.locations = locations.compact

      excludes = (config.excludes||[]).collect do |pattern|
        Regexp.new(pattern)
      end
      config.excludes = excludes

      unless config.hostname
        raise "Config MUST have a hostname"
      end

      base_dir = config.base_dir
      config.scanner_dir = File.join(base_dir, "scanner")
      config.backup_dir = File.join(base_dir, "backup")
      config.data_dir = File.join(base_dir, "data")
      config.scanner_pid_file = File.join(base_dir, "scanner.pid")
      config.backup_pid_file = File.join(base_dir, "backup.pid")
      config.log_dir = File.join(base_dir, "log")

      config
    end
    
  end
end
