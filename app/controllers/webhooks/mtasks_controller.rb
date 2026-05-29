module Webhooks
  class MtasksController < ActionController::API
    include WebhookSignatureVerification

    before_action :load_integration
    before_action :verify_signature
    before_action :verify_timestamp, if: -> { @integration.verify_webhook_timestamp }

    def create
      delivery_id = request.headers['X-Mtasks-Delivery'].presence || parsed_payload['delivery_id']
      event_type  = request.headers['X-Mtasks-Event'].presence || parsed_payload['event']

      return head :bad_request if delivery_id.blank? || event_type.blank?
      return head :ok if WebhookDelivery.exists?(source: WebhookDelivery::SOURCE_MTASKS, delivery_id: delivery_id)

      persist_and_enqueue(delivery_id: delivery_id, event_type: event_type)
      head :ok
    rescue ActiveRecord::RecordNotUnique
      head :ok
    end

    private

    def persist_and_enqueue(delivery_id:, event_type:)
      delivery = WebhookDelivery.create!(
        source: WebhookDelivery::SOURCE_MTASKS,
        delivery_id: delivery_id,
        event_type: event_type,
        received_at: Time.current,
        payload: parsed_payload
      )
      MtasksWebhookProcessorJob.perform_later(delivery.id)
    end

    def load_integration
      @integration = ServerIntegration.enabled
                                      .for_kind(ServerIntegration::KIND_JAIT)
                                      .find_by(id: params[:integration_id])
      head :not_found unless @integration
    end

    def verify_signature
      verify_webhook_signature!(
        secret: @integration.webhook_secret.to_s,
        signature_header: request.headers['X-Mtasks-Signature-256'],
        body: request.raw_post
      )
    end

    def verify_timestamp
      verify_webhook_timestamp!(timestamp_header: request.headers['X-Mtasks-Timestamp'])
    end

    def parsed_payload
      @parsed_payload ||= JSON.parse(request.raw_post)
    rescue JSON::ParserError
      {}
    end
  end
end
