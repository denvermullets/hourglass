class Channels::ReorderService < Service
  def initialize(channel:, direction:)
    @channel = channel
    @direction = direction
  end

  def call
    sibling = find_sibling
    return unless sibling

    ActiveRecord::Base.transaction do
      old_position = @channel.position
      @channel.update!(position: sibling.position)
      sibling.update!(position: old_position)
    end
  end

  private

  def find_sibling
    scope = @channel.category.channels
    if @direction == :up
      scope.where('position < ?', @channel.position).order(position: :desc).first
    else
      scope.where('position > ?', @channel.position).order(position: :asc).first
    end
  end
end
