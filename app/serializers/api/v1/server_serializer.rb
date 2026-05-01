module Api
  module V1
    class ServerSerializer
      def initialize(server)
        @server = server
      end

      def as_json(*)
        {
          id: @server.id,
          name: @server.name,
          description: @server.description
        }
      end
    end
  end
end
