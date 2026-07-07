class Channels::AddMemberService < Service
  def initialize(channel:, user:)
    @channel = channel
    @user = user
  end

  def call
    ChannelMembership.find_or_create_by!(channel: @channel, user: @user)
  end
end
