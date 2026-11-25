require 'minitest/autorun'
require 'stringio'
require_relative '../lib/sessionizer'

class SessionizerTest < Minitest::Test
  def parse(text)
    Sessionizer.read(StringIO.new("user_id,timestamp,event\n" + text))
  end

  def test_sorted_sessions_and_exact_gap_boundary
    events = File.open(File.join(__dir__, '../fixtures/events.csv')) { |f| Sessionizer.read(f) }
    sessions = Sessionizer.group(events, gap_seconds: 1800)
    assert_equal 3, sessions.length
    assert_equal ['alice', 'alice', 'bob'], sessions.map(&:user)
    assert_equal [3, 1, 1], sessions.map(&:count)
    assert_equal 1800, sessions[0].ended - sessions[0].started
    assert_equal ['login', 'view'], sessions[0].names
    assert_equal [1, 2, 1], sessions.map(&:index)
  end

  def test_timezones_normalize_and_ties_preserve_source_order
    events = parse("u,2025-01-01T01:00:00+01:00,first\nu,2025-01-01T00:00:00Z,second\n")
    result = Sessionizer.group(events, gap_seconds: 0)
    assert_equal 1, result.length
    assert_equal %w[first second], result.first.names
  end

  def test_fractional_gap_and_output_escaping
    events = parse("\"u,1\",2025-01-01T00:00:00.100000Z,\"open,details\"\n\"u,1\",2025-01-01T00:00:00.200000Z,next\n")
    result = Sessionizer.group(events, gap_seconds: 1)
    out = StringIO.new
    Sessionizer.write(result, out)
    row = CSV.parse(out.string, headers: true).first
    assert_equal 'u,1', row['user_id']
    assert_equal ['open,details', 'next'], JSON.parse(row['event_names_json'])
    assert_equal '0.1', row['duration_seconds']
  end

  def test_invalid_data_and_empty_input
    assert_raises(ArgumentError) { parse("u,2025-02-30T00:00:00Z,login\n") }
    assert_raises(ArgumentError) { parse("u,2025-01-01T00:00:00,login\n") }
    assert_raises(ArgumentError) { parse(",2025-01-01T00:00:00Z,login\n") }
    assert_raises(ArgumentError) { Sessionizer.read(StringIO.new("user_id,user_id,event\n")) }
    assert_raises(ArgumentError) { Sessionizer.group([], gap_seconds: -1) }
    assert_empty Sessionizer.group(parse(''))
  end
end
