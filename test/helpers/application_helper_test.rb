require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  setup do
    @user = users(:one)
    Current.session = @user.sessions.create!
  end

  teardown do
    Current.session = nil
  end

  # -- user_timezone --

  test 'user_timezone defaults to UTC' do
    assert_equal ActiveSupport::TimeZone['UTC'], user_timezone
  end

  test 'user_timezone returns configured zone' do
    @user.update!(settings: { 'appearance' => { 'timezone' => 'Eastern Time (US & Canada)' } })
    assert_equal ActiveSupport::TimeZone['Eastern Time (US & Canada)'], user_timezone
  end

  test 'user_timezone falls back to UTC for invalid zone' do
    @user.update!(settings: { 'appearance' => { 'timezone' => 'Fake/Zone' } })
    assert_equal ActiveSupport::TimeZone['UTC'], user_timezone
  end

  # -- local_date --

  test 'local_date converts UTC time to user timezone date' do
    @user.update!(settings: { 'appearance' => { 'timezone' => 'Tokyo' } })
    # 11pm UTC on March 15 is March 16 in Tokyo (UTC+9)
    utc_time = Time.utc(2026, 3, 15, 23, 0, 0)
    assert_equal Date.new(2026, 3, 16), local_date(utc_time)
  end

  test 'local_date stays same date when timezone matches' do
    utc_time = Time.utc(2026, 3, 15, 12, 0, 0)
    assert_equal Date.new(2026, 3, 15), local_date(utc_time)
  end

  # -- format_timestamp absolute --

  test 'absolute message format shows date and time in user timezone' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'absolute',
                                                'timezone' => 'Eastern Time (US & Canada)' } })
    time = Time.utc(2026, 3, 15, 17, 30, 0) # 5:30 PM UTC = 1:30 PM EDT
    result = format_timestamp(time, style: :message)
    assert_equal '3/15/2026 1:30 PM', result
  end

  test 'absolute reply format matches message format in user timezone' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'absolute', 'timezone' => 'Tokyo' } })
    time = Time.utc(2026, 3, 15, 14, 30, 45) # 2:30:45 PM UTC = 11:30:45 PM JST
    result = format_timestamp(time, style: :reply)
    assert_equal '3/15/2026 11:30 PM', result
  end

  test 'absolute thread_root format' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'absolute', 'timezone' => 'UTC' } })
    time = Time.utc(2026, 3, 15, 14, 30, 45)
    result = format_timestamp(time, style: :thread_root)
    assert_equal 'mar 15 · 2:30:45 pm', result
  end

  test 'absolute thread_breadcrumb format' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'absolute', 'timezone' => 'UTC' } })
    time = Time.utc(2026, 3, 15, 14, 30, 0)
    result = format_timestamp(time, style: :thread_breadcrumb)
    assert_equal 'mar 15 · 2:30 pm', result
  end

  test 'absolute date_separator format' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'absolute', 'timezone' => 'Tokyo' } })
    time = Time.utc(2026, 3, 15, 23, 0, 0)
    result = format_timestamp(time, style: :date_separator)
    assert_equal 'March 16, 2026', result
  end

  test 'absolute notification format' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'absolute', 'timezone' => 'UTC' } })
    time = Time.utc(2026, 3, 15, 14, 30, 0)
    result = format_timestamp(time, style: :notification)
    assert_equal '3/15/2026 2:30 PM', result
  end

  # -- format_timestamp relative --

  test 'relative message format shows just now for recent' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'relative', 'timezone' => 'UTC' } })
    result = format_timestamp(30.seconds.ago, style: :message)
    assert_equal 'just now', result
  end

  test 'relative message format shows minutes ago' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'relative', 'timezone' => 'UTC' } })
    result = format_timestamp(5.minutes.ago, style: :message)
    assert_equal '5m ago', result
  end

  test 'relative message format shows today at time' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'relative', 'timezone' => 'UTC' } })
    time = Time.current.in_time_zone('UTC').change(hour: 10, min: 30) - 2.hours
    # Only test if the time is still today
    if time.to_date == Time.current.in_time_zone('UTC').to_date && (Time.current - time) >= 3600
      result = format_timestamp(time, style: :message)
      assert_match(/today at/, result)
    end
  end

  test 'relative message format falls back to absolute for old dates' do
    @user.update!(settings: { 'appearance' => { 'timestamp_format' => 'relative', 'timezone' => 'UTC' } })
    time = Time.utc(2025, 1, 15, 14, 30, 0)
    result = format_timestamp(time, style: :message)
    assert_equal '1/15/2025 2:30 PM', result
  end

  # -- Date object fallback --

  test 'format_timestamp handles Date objects gracefully' do
    result = format_timestamp(Date.new(2026, 3, 15), style: :date_separator)
    assert_equal 'March 15, 2026', result
  end
end
