module Api
  module V1
    class BaseController < ActionController::API
      SAFE_METHODS = %w[GET HEAD].freeze
      PAGE_DEFAULT = 50
      PAGE_MAX = 100

      before_action :authenticate_api_token!
      before_action :authorize_api_token_scope!

      private

      def authenticate_api_token!
        token_string = request.headers['Authorization']&.delete_prefix('Bearer ')&.strip
        api_token = ApiToken.authenticate(token_string)

        if api_token
          @current_api_token = api_token
          Current.user = api_token.user
          api_token.touch_used!
        else
          render json: { error: 'Unauthorized', message: 'Invalid or missing API token' },
                 status: :unauthorized
        end
      end

      def authorize_api_token_scope!
        return unless @current_api_token

        required = SAFE_METHODS.include?(request.method) ? 'read' : 'write'
        return if @current_api_token.has_scope?(required)

        render json: { error: 'Forbidden', message: 'Token lacks required scope' },
               status: :forbidden
      end

      def current_user
        Current.user
      end

      def render_validation_errors(record)
        render json: { error: 'Unprocessable Entity', errors: record.errors.full_messages },
               status: :unprocessable_entity
      end

      def paginate(scope, since_param: :since, limit_param: :limit)
        limit = [params[limit_param].to_i, PAGE_MAX].min
        limit = PAGE_DEFAULT if limit <= 0
        scope = scope.where('id > ?', params[since_param]) if params[since_param].present?
        scope.order(id: :asc).limit(limit)
      end
    end
  end
end
