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

    membership
  end
end
