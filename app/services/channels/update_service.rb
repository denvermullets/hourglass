class Channels::UpdateService < Service
  def initialize(channel:, params:)
    @channel = channel
    @params = params
  end

  def call
    @channel.update!(@params)
    @channel
  end
end
