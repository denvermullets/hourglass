module Api
  module V1
    module Idempotency
      extend ActiveSupport::Concern

      CACHEABLE_STATUSES = (200..299).to_a + (400..499).to_a
      TTL = 24.hours

      included do
        before_action :replay_idempotent_response, only: %i[create create_reply]
        after_action  :store_idempotent_response,  only: %i[create create_reply]
      end

      private

      def idempotency_key
        @idempotency_key ||= request.headers['Idempotency-Key'].presence
      end

      def idempotency_cache_key
        "api/v1/idempotency:#{@current_api_token.id}:#{idempotency_key}"
      end

      def replay_idempotent_response
        return unless idempotency_key

        cached = Rails.cache.read(idempotency_cache_key)
        return unless cached

        render json: cached[:body], status: cached[:status]
      end

      def store_idempotent_response
        return unless idempotency_key
        return unless CACHEABLE_STATUSES.include?(response.status)

        Rails.cache.write(
          idempotency_cache_key,
          { status: response.status, body: JSON.parse(response.body) },
          expires_in: TTL
        )
      end
    end
  end
end
