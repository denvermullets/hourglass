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
  end

  private

  def mark_single
    @user = @notification.user
    @notification.mark_read!
  end

  def mark_all
    @user.notifications.unread.update_all(read_at: Time.current)
  end
end
