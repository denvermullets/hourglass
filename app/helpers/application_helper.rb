module ApplicationHelper
  # Content digest for the polling-based refresh. Reads the current page context from
  # controller ivars (nil off chat pages — sidebar/notification parts still apply).
  def poll_digest
    return unless Current.user

    Polling::DigestService.call(
      user: Current.user,
      channel: @channel,
      conversation: @conversation,
      thread: @parent_message
    )
  end

  def user_timezone
    zone_name = Current.user&.timezone || 'UTC'
    ActiveSupport::TimeZone[zone_name] || ActiveSupport::TimeZone['UTC']
  end

  def local_date(time)
    time.in_time_zone(user_timezone).to_date
  end

  def format_timestamp(time, style: :message)
    return time.strftime('%B %-d, %Y') if time.is_a?(Date) && !time.is_a?(Time)

    zone = user_timezone
    local = time.in_time_zone(zone)
    fmt = Current.user&.timestamp_format || 'relative'

    case fmt
    when 'relative'
      format_relative_timestamp(local, zone, style)
    else
      format_absolute_timestamp(local, style)
    end
  end

  private

  def format_relative_timestamp(local, zone, style)
    case style
    when :message, :reply
      relative_message_timestamp(local, zone)
    when :notification
      "#{time_ago_in_words(local)} ago"
    else
      format_absolute_timestamp(local, style)
    end
  end

  def relative_message_timestamp(local, zone)
    now = Time.current.in_time_zone(zone)
    diff = (now - local).to_i

    if diff < 60
      'just now'
    elsif diff < 3600
      "#{diff / 60}m ago"
    elsif local.to_date == now.to_date
      "today at #{local.strftime('%-I:%M %p').downcase}"
    elsif local.to_date == (now - 1.day).to_date
      "yesterday at #{local.strftime('%-I:%M %p').downcase}"
    else
      local.strftime('%-m/%-d/%Y %-I:%M %p')
    end
  end

  def format_absolute_timestamp(local, style)
    case style
    when :message, :notification, :reply
      local.strftime('%-m/%-d/%Y %-I:%M %p')
    when :thread_root
      local.strftime('%b %d · %-I:%M:%S %p').downcase
    when :thread_breadcrumb
      local.strftime('%b %d · %-I:%M %p').downcase
    when :date_separator
      local.strftime('%B %-d, %Y')
    end
  end
end
