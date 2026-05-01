module Api
  module V1
    class UsersController < BaseController
      def me
        render json: UserSerializer.new(current_user).as_json
      end
    end
  end
end
