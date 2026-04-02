module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :current_membership
  end

  private

  def current_membership
    @current_membership ||= @server&.membership_for(Current.user)
  end

  def require_membership!
    return if current_membership

    redirect_to servers_path, alert: 'You are not a member of this server.'
  end

  def require_role!(role)
    require_membership!
    return if performed?

    return if current_membership.at_least?(role)

    redirect_to server_path(@server), alert: "You don't have permission to do that."
  end

  def require_moderator!
    require_role!(:moderator)
  end

  def require_admin!
    require_role!(:admin)
  end

  def require_owner!
    require_role!(:owner)
  end

  def unread_channel_ids_for_server(server)
    channels_with_messages = server.channels
                                   .visible_to(Current.user)
                                   .where.not(last_message_at: nil)
                                   .pluck(:id, :last_message_at)
                                   .to_h

    return Set.new if channels_with_messages.empty?

    read_times = ChannelMembership
                 .where(user: Current.user, channel_id: channels_with_messages.keys)
                 .pluck(:channel_id, :last_read_at)
                 .to_h

    unread = Set.new
    channels_with_messages.each do |ch_id, last_msg_at|
      last_read = read_times[ch_id]
      unread.add(ch_id) if last_read.nil? || last_msg_at > last_read
    end
    unread
  end
end
