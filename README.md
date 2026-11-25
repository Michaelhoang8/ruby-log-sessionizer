# Event log sessionizer

Convert timestamped event CSV into per-user sessions. Events are sorted by user and time, so input need not arrive in chronological order. Original row order resolves timestamp ties.

```sh
ruby test/sessionizer_test.rb
ruby bin/sessionize.rb --gap 1800 fixtures/events.csv
```

Input columns must be exactly `user_id,timestamp,event`. Timestamps require an explicit UTC offset or Z suffix and support up to six fractional-second digits. Invalid dates, missing fields and blank user/event names are rejected before output is written.

A new session starts when the time since that user's previous event is **greater than** the gap. A gap exactly equal to 1,800 seconds stays in the same session. Output includes a per-user session index, UTC start/end times, duration, count and a JSON array of distinct event names inside the CSV field.

Tests cover out-of-order inputs, exact thresholds, timezone equivalence, simultaneous events, fractional seconds, CSV quoting, empty input and validation errors. All four tests and 18 assertions passed with Ruby 3.2.3 in an Ubuntu container. The CLI output was independently checked for three sessions and correct event counts. Requires Ruby 3.1 or newer with the standard CSV library and Minitest. Ubuntu CI repeats the tests.

The program retains all events in memory and has no cross-file state. Session grouping expresses an inactivity rule; it does not identify people across devices or infer intent.
