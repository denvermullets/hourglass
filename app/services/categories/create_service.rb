class Categories::CreateService < Service
  def initialize(server:, params:)
    @server = server
    @params = params
  end

  def call
    position = @server.categories.maximum(:position).to_i + 1
    category = @server.categories.create!(@params.merge(position: position))
    Sidebar::BroadcastService.call(server: @server, action: :replace_all_categories)
    category
  end
end
