class Servers::UpdatePermissionsService < Service
  def initialize(server:, permissions:)
    @server = server
    @permissions = permissions
  end

  def call
    merged = @server.settings.merge('permissions' => @permissions)
    @server.update!(settings: merged)
  end
end
