class Servers::UpdateSettingsService < Service
  def initialize(server:, params:)
    @server = server
    @params = params
  end

  def call
    @server.update!(@params)
    @server
  end
end
