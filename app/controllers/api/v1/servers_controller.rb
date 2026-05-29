module Api
  module V1
    class ServersController < BaseController
      def index
        servers = current_user.servers.order(:name)
        render json: servers.map { |s| ServerSerializer.new(s).as_json }
      end

      def show
        server = current_user.servers.find_by(id: params[:id])
        return render_not_found unless server

        render json: ServerSerializer.new(server).as_json
      end

      private

      def render_not_found
        render json: { error: 'Not Found', message: 'Server not found' }, status: :not_found
      end
    end
  end
end
