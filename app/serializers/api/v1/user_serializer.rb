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
          server: serialized_server
        }
      end

      private

      def serialized_server
        server = @user.servers.order(:id).first
        return nil unless server

        { id: server.id, name: server.name }
      end
    end
  end
end
