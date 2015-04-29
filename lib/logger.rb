require 'fileutils'

module Backup
  class Logger

    attr_reader :logfile
    def initialize(name, log_dir)
      @logfilename = File.join(log_dir, "#{name}_#{Time.now.to_i}_#{rand(1000)}.log")
      @logfile = File.open(@logfilename, "a")
      @log_open = true
      self.class.registerLogger(self)
    end

    def close
      return unless @log_open
      @logfile.close
      @log_open = false
    end

    def log_open?
      @log_open
    end
    
    def log(text, options={})
      logfile << text
      if text[-1] != "\n"
        logfile << "\n"
      end
      if options[:verbose]
        puts text
      end
    end

    def self.registerLogger(logger)
      @logger = logger
    end
    
    def self.log_command(command, output)
      text = "#{Time.now.to_s}\n"
      text << "#{command}\n"
      text << "---\n"
      text << output
      text << "\n---\n"
      self.log(text)
    end

    def self.log_line(line)
      self.log("#{Time.now} | #{line}\n")
      puts line
    end

    def self.log(text, options={})
      if @logger && @logger.log_open?
        @logger.log(text, options)
      else
        puts text
      end
    end

    def self.log_exception(e)
      self.log("#{Time.now} | Exception: #{e.message}\nBacktrace:\n#{e.backtrace.join("\n")}\n", verbose: true)
    end

  end
end
