class Categories::CreateService < Service
  def initialize(server:, params:)
    @server = server
    @params = params
  end

  def call
    position = @server.categories.maximum(:position).to_i + 1
    @server.categories.create!(@params.merge(position: position))
  end
end
