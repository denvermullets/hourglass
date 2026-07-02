class Channels::UnarchiveService < Service
  def initialize(channel:)
    @channel = channel
  end

  def call
    @channel.unarchive!
  end
end
