require 'yaml'

module Backup
  class Config
    def initialize(config_filename)
      @config_filename = config_filename
      @config = YAML.load_file(config_filename)
      resolve_locations(@config, @config_filename)
      process_excludes(@config)
      set_defaults(@config)
    end


    private
    def resolve_locations(config, config_filename)
      locations = []
      config["locations"].each do |path|
        if !path.match(/^\//)
          path = File.join(File.dirname(config_filename), path)
        end
        path = File.expand_path(path)
        locations << path
      end
      config["locations"] = locations
    end

    def process_excludes(config)
      excludes = []
      (config["excludes"]||[]).each do |pattern|
        excludes << Regexp.new(pattern)
      end
      config["excludes"] = excludes
    end

    def set_defaults(config)
      config["working_dir"] ||= File.join("data", "atlantis", "backup", "working")
      config["scanner_dir"] ||= File.join("data", "atlantis", "backup", "scanner")
      config["data_dir"] ||= File.join("data", "atlantis", "backup", "data")
      config["pid_file"] ||= File.join(ENV["HOME"], "log", "atlantis", "backup", "scanner.pid")
      config["log_dir"] ||= File.join(ENV["HOME"], "log", "atlantis", "backup")
    end
  end
end
