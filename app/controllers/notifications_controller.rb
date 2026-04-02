class NotificationsController < ApplicationController
  layout 'app'

  def index
    @notifications = Current.user.notifications.feed.includes(:actor)
    render layout: false
  end

  def mark_read
    notification = Current.user.notifications.find(params[:id])
    Notifications::MarkReadService.call(notification: notification)
    head :ok
  end

  def mark_all_read
    Notifications::MarkReadService.call(user: Current.user)
    Channels::MarkAllReadService.call(user: Current.user)
    head :ok
  end
end
