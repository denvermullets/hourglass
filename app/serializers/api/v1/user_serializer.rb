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
          display_name: @user.display_name
        }
      end
    end
  end
end
