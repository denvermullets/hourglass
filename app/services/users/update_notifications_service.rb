class Users::UpdateNotificationsService < Service
  def initialize(user:, notification_params:, muted_channel_ids: [])
    @user = user
    @notification_params = notification_params
    @muted_channel_ids = muted_channel_ids.map(&:to_i)
  end

  def call
    current = @user.settings || {}
    notifications = current.fetch('notifications', {})

    %w[direct_messages mentions thread_replies reactions].each do |key|
      notifications[key] = @notification_params[key] == 'true' if @notification_params.key?(key)
    end

    notifications['email_digest'] = @notification_params[:email_digest] if @notification_params.key?(:email_digest)

    @user.update!(settings: current.merge('notifications' => notifications))

    @user.channel_memberships.update_all(muted: false)
    @user.channel_memberships.where(channel_id: @muted_channel_ids).update_all(muted: true) if @muted_channel_ids.any?

    @user
  end
end
