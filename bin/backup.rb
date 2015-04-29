require File.join(File.dirname(__FILE__), "../lib/file_backup")

f = FileBackup.new(ARGV[0])
f.work

