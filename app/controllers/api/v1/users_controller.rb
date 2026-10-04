module Api
  module V1
    class UsersController < BaseController
      def me
        render json: UserSerializer.new(current_user, server: token_server).as_json
      end
    end
  end
end
