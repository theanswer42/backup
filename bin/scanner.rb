require File.join(File.dirname(__FILE__), "../lib/file_scanner")

f = FileScanner.new(ARGV[0])
f.scan

