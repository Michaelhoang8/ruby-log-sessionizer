require 'optparse'
require_relative '../lib/sessionizer'

begin
  gap = 1800
  parser = OptionParser.new do |options|
    options.banner = 'Usage: ruby bin/sessionize.rb [--gap SECONDS] events.csv'
    options.on('--gap SECONDS', Integer) { |value| gap = value }
  end
  parser.parse!
  raise ArgumentError, parser.to_s unless ARGV.length == 1
  events = File.open(ARGV[0], 'r:bom|utf-8') { |file| Sessionizer.read(file) }
  Sessionizer.write(Sessionizer.group(events, gap_seconds: gap), $stdout)
rescue ArgumentError, CSV::MalformedCSVError, SystemCallError => e
  warn e.message
  exit 2
end
