class Channels::MarkReadService < Service
  def initialize(channel:, user:)
    @channel = channel
    @user = user
  end

  def call
    membership = ChannelMembership.find_or_create_by!(
      user: @user,
      channel: @channel
    )
    membership.mark_read!

    broadcast_read_indicator
    membership
  end

  private

  def broadcast_read_indicator
    target_id = "unread_indicator_channel_#{@channel.id}"
    classes = 'flex-shrink-0 ml-auto flex items-center'

    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{@user.id}_unread",
      target: target_id,
      html: "<span id=\"#{target_id}\" data-unread=\"false\" class=\"#{classes}\"></span>"
    )

    broadcast_title_indicator
  end

  def broadcast_title_indicator
    has_unread = any_unread_channels?
    inner = has_unread ? '<span data-unread="true"></span>' : ''
    html = "<span id=\"unread_title_indicator\" class=\"hidden\">#{inner}</span>"

    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{@user.id}_unread_title",
      target: 'unread_title_indicator',
      html: html
    )
  end

  def any_unread_channels?
    return true if @user.unread_conversations?

    server = @channel.server
    channels = server.channels
                     .visible_to(@user)
                     .where.not(last_message_at: nil)
                     .pluck(:id, :last_message_at)

    return false if channels.empty?

    read_times = ChannelMembership
                 .where(user: @user, channel_id: channels.map(&:first))
                 .pluck(:channel_id, :last_read_at)
                 .to_h

    channels.any? do |ch_id, last_msg_at|
      last_read = read_times[ch_id]
      last_read.nil? || last_msg_at > last_read
    end
  end
end
