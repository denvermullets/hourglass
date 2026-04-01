class Notifications::MarkReadService < Service
  def initialize(notification: nil, user: nil)
    @notification = notification
    @user = user
  end

  def call
    if @notification
      mark_single
    elsif @user
      mark_all
    end

    broadcast_badge_update
  end

  private

  def mark_single
    @user = @notification.user
    @notification.mark_read!
  end

  def mark_all
    @user.notifications.unread.update_all(read_at: Time.current)
  end

  def broadcast_badge_update
    return unless @user

    count = @user.reload.unread_notification_count
    html = Notifications::StreamBuilder.badge_streams(count)
    NotificationsChannel.broadcast_to(@user, { html: html })
  end
end
