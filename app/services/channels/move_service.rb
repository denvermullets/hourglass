class Channels::MoveService < Service
  def initialize(channel:, category:)
    @channel = channel
    @category = category
  end

  def call
    return if @channel.category_id == @category.id

    position = @category.channels.maximum(:position).to_i + 1
    @channel.update!(category: @category, position: position)
  end
end
