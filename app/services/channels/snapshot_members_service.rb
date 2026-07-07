class Channels::SnapshotMembersService < Service
  # Provisions a channel_membership for every current member of the channel's
  # server, granting them access to a (now) private channel. Idempotent — existing
  # rows (and their read state) are preserved.
  def initialize(channel:)
    @channel = channel
  end

  def call
    @channel.server.users.find_each do |user|
      ChannelMembership.find_or_create_by!(channel: @channel, user: user)
    end
    @channel
  end
end
