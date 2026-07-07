class Channels::UpdateService < Service
  def initialize(channel:, params:)
    @channel = channel
    @params = params
  end

  def call
    was_private = @channel.is_private?
    @channel.update!(@params)
    # When a channel is switched to private, snapshot all current server members
    # so they keep access. New members must be added explicitly afterwards.
    Channels::SnapshotMembersService.call(channel: @channel) if !was_private && @channel.is_private?
    @channel
  end
end
