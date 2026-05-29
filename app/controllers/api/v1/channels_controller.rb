module Api
  module V1
    class ChannelsController < BaseController
      def index
        server = current_user.servers.find_by(id: params[:server_id])
        return render_not_found('Server not found') unless server

        channels = server.channels.active.visible_to(current_user).ordered
        render json: channels.map { |c| ChannelSerializer.new(c).as_json }
      end

      def show
        channel = Channel.visible_to(current_user).find_by(id: params[:id])
        return render_not_found('Channel not found') unless channel

        render json: ChannelSerializer.new(channel).as_json
      end

      private

      def render_not_found(message)
        render json: { error: 'Not Found', message: message }, status: :not_found
      end
    end
  end
end
