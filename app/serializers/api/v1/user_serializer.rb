module Api
  module V1
    class UserSerializer
      def initialize(user)
        @user = user
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

      def server
        @server ||= @user.servers.order(:id).first
      end

      def serialized_server
        return nil unless server

        { id: server.id, name: server.name }
      end

      def serialized_integration
        integration = server&.jait_integration
        return nil unless integration

        { id: integration.id, webhook_secret: integration.webhook_secret }
      end
    end
  end
end
