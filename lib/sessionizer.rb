require 'csv'
require 'date'
require 'time'
require 'json'

module Sessionizer
  Event = Struct.new(:user, :at, :name, :source_row, keyword_init: true)
  Session = Struct.new(:user, :index, :started, :ended, :count, :names, keyword_init: true)
  REQUIRED = %w[user_id timestamp event].freeze
  STAMP = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})\z/

  def self.read(io)
    csv = CSV.new(io, headers: true)
    events = []
    csv.each.with_index(2) do |row, number|
      raise ArgumentError, 'expected exactly user_id,timestamp,event headers' unless row.headers.none?(&:nil?) && row.headers.sort == REQUIRED.sort
      raise ArgumentError, "row #{number}: extra or missing fields" if row.fields.length != 3 || row.fields.any?(&:nil?)
      user, timestamp, name = REQUIRED.map { |key| row[key] }
      raise ArgumentError, "row #{number}: blank user or event" if user.strip.empty? || name.strip.empty?
      raise ArgumentError, "row #{number}: timestamp requires an explicit timezone" unless STAMP.match?(timestamp)
      begin
        at = DateTime.iso8601(timestamp).to_time.utc
      rescue Date::Error, ArgumentError
        raise ArgumentError, "row #{number}: invalid timestamp"
      end
      events << Event.new(user: user, at: at, name: name, source_row: number)
    end
    raise ArgumentError, 'expected exactly user_id,timestamp,event headers' unless csv.headers&.sort == REQUIRED.sort
    events
  end

  # A gap equal to the threshold remains in the same session.
  # Stable source-row ordering resolves events with identical timestamps.
  def self.group(events, gap_seconds: 1800)
    raise ArgumentError, 'gap_seconds must be a nonnegative integer' unless gap_seconds.is_a?(Integer) && gap_seconds >= 0
    sessions = []
    events.group_by(&:user).sort.each do |user, records|
      current = nil
      index = 0
      records.sort_by { |event| [event.at, event.source_row] }.each do |event|
        if current.nil? || event.at - current.ended > gap_seconds
          index += 1
          current = Session.new(user: user, index: index, started: event.at, ended: event.at, count: 0, names: [])
          sessions << current
        end
        current.ended = event.at
        current.count += 1
        current.names << event.name unless current.names.include?(event.name)
      end
    end
    sessions
  end

  def self.write(sessions, io)
    output = CSV.new(io)
    output << %w[user_id session_index started_at ended_at duration_seconds event_count event_names_json]
    sessions.each do |s|
      output << [s.user, s.index, s.started.iso8601(6), s.ended.iso8601(6),
                 (s.ended - s.started).round(6), s.count, JSON.generate(s.names)]
    end
    output.flush
  end
end
