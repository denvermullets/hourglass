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
      html: "<span id=\"#{target_id}\" class=\"#{classes}\"></span>"
    )
  end
end
