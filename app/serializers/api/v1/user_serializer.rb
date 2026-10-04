module Api
  module V1
    # `server` is the server the API token is bound to. Unbound tokens get
    # server/integration nil so callers can't guess which server they hit.
    class UserSerializer
      def initialize(user, server: nil)
        @user = user
        @server = server
      end

      def as_json(*)
        {
          id: @user.id,
          email: @user.email_address,
          display_name: @user.display_name,
          server: serialized_server,
          integration: serialized_integration
        }
      end

      private

      def serialized_server
        return nil unless @server

        { id: @server.id, name: @server.name }
      end

      def serialized_integration
        integration = @server&.jait_integration
        return nil unless integration

        { id: integration.id, webhook_secret: integration.webhook_secret }
      end
    end
  end
end
