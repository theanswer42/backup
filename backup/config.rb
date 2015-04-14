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

      base_dir = config.base_dir
      config.working_dir = File.join(base_dir, "working")
      config.scanner_dir = File.join(base_dir, "scanner")
      config.data_dir = File.join(base_dir, "data")
      config.pid_file = File.join(base_dir, "run", "scanner.pid")
      config.log_dir = File.join(base_dir, "log")

      config
    end
    
  end
end
