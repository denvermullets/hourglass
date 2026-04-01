class Notifications::CreateService < Service
  SETTINGS_KEY_MAP = {
    'mention' => 'mentions',
    'reply' => 'thread_replies',
    'reaction' => 'reactions',
    'dm' => 'direct_messages'
  }.freeze

  def initialize(user:, actor:, notification_type:, notifiable:, data: {})
    @user = user
    @actor = actor
    @notification_type = notification_type.to_s
    @notifiable = notifiable
    @data = data
  end

  def call
    return if @user == @actor
    return unless notification_enabled?
    return if channel_muted?
    return if recently_notified?

    notification = Notification.create!(
      user: @user,
      actor: @actor,
      notification_type: @notification_type,
      notifiable: @notifiable,
      data: @data
    )

    broadcast_to_user(notification)
    notification
  end

  private

  def notification_enabled?
    settings_key = SETTINGS_KEY_MAP[@notification_type]
    return true unless settings_key

    @user.notification_setting(settings_key) != false
  end

  def channel_muted?
    return false unless @notifiable.respond_to?(:channel) && @notifiable.channel.present?

    membership = ChannelMembership.find_by(user: @user, channel: @notifiable.channel)
    membership&.muted?
  end

  def recently_notified?
    Notification.where(
      user: @user,
      notification_type: @notification_type,
      notifiable: @notifiable
    ).where('created_at > ?', 5.minutes.ago).exists?
  end

  def broadcast_to_user(notification)
    count = @user.unread_notification_count
    html = Notifications::StreamBuilder.badge_streams(count)
    html += Notifications::StreamBuilder.notification_stream(notification)
    NotificationsChannel.broadcast_to(@user, { html: html })
  end
end
