class Channels::ArchiveService < Service
  def initialize(channel:)
    @channel = channel
  end

  def call
    @channel.archive!
  end
end
