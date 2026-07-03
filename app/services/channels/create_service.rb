class Channels::CreateService < Service
  def initialize(server:, category:, params:)
    @server = server
    @category = category
    @params = params
  end

  def call
    position = @category.channels.maximum(:position).to_i + 1
    @server.channels.create!(
      @params.merge(category: @category, position: position)
    )
  end
end
