class Channels::UnarchiveService < Service
  def initialize(channel:)
    @channel = channel
  end

  def call
    @channel.unarchive!
    Sidebar::BroadcastService.call(server: @channel.server, action: :replace_category, category: @channel.category)
  end
end
