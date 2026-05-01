require 'test_helper'

module Webhooks
  class MtasksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @integration = server_integrations(:jait_one)
      @secret = @integration.webhook_secret
    end

    def signed_headers(body, secret: @secret, timestamp: Time.current.to_i, delivery_id: SecureRandom.uuid,
                       event: 'link.created')
      {
        'Content-Type' => 'application/json',
        'X-Mtasks-Event' => event,
        'X-Mtasks-Delivery' => delivery_id,
        'X-Mtasks-Timestamp' => timestamp.to_s,
        'X-Mtasks-Signature-256' => "sha256=#{OpenSSL::HMAC.hexdigest('sha256', secret, body)}"
      }
    end

    def envelope(event:, delivery_id:, data: {})
      { version: 1, event: event, delivery_id: delivery_id, data: data }.to_json
    end

    test 'happy path: persists delivery, enqueues job, returns 200' do
      delivery_id = SecureRandom.uuid
      body = envelope(event: 'link.created', delivery_id: delivery_id,
                      data: { link_type: 'project_channel', mtasks_project_id: '1', hourglass_channel_id: '99' })

      assert_difference 'WebhookDelivery.count', 1 do
        assert_enqueued_with(job: MtasksWebhookProcessorJob) do
          post webhooks_mtasks_path(@integration), params: body,
                                                   headers: signed_headers(body, delivery_id: delivery_id)
        end
      end
      assert_response :ok

      delivery = WebhookDelivery.last
      assert_equal 'mtasks', delivery.source
      assert_equal delivery_id, delivery.delivery_id
      assert_equal 'link.created', delivery.event_type
      assert_equal 'project_channel', delivery.payload.dig('data', 'link_type')
    end

    test '404 when integration_id is unknown' do
      body = envelope(event: 'link.created', delivery_id: SecureRandom.uuid)
      post webhooks_mtasks_path(integration_id: 999_999), params: body, headers: signed_headers(body)
      assert_response :not_found
    end

    test '404 when integration is disabled' do
      @integration.update!(enabled: false)
      body = envelope(event: 'link.created', delivery_id: SecureRandom.uuid)
      post webhooks_mtasks_path(@integration), params: body, headers: signed_headers(body)
      assert_response :not_found
    end

    test '401 when signature header is missing' do
      body = envelope(event: 'link.created', delivery_id: SecureRandom.uuid)
      headers = signed_headers(body).except('X-Mtasks-Signature-256')

      assert_no_difference 'WebhookDelivery.count' do
        assert_no_enqueued_jobs do
          post webhooks_mtasks_path(@integration), params: body, headers: headers
        end
      end
      assert_response :unauthorized
    end

    test '401 when signature is wrong (different secret)' do
      body = envelope(event: 'link.created', delivery_id: SecureRandom.uuid)
      headers = signed_headers(body, secret: 'wrong-secret')

      assert_no_difference 'WebhookDelivery.count' do
        post webhooks_mtasks_path(@integration), params: body, headers: headers
      end
      assert_response :unauthorized
    end

    test '401 when timestamp is outside replay window' do
      body = envelope(event: 'link.created', delivery_id: SecureRandom.uuid)
      stale = (Time.current - 6.minutes).to_i
      post webhooks_mtasks_path(@integration), params: body, headers: signed_headers(body, timestamp: stale)
      assert_response :unauthorized
    end

    test 'stale timestamp accepted when verify_webhook_timestamp is false' do
      @integration.update!(verify_webhook_timestamp: false)
      body = envelope(event: 'link.created', delivery_id: SecureRandom.uuid)
      stale = (Time.current - 6.minutes).to_i

      assert_difference 'WebhookDelivery.count', 1 do
        post webhooks_mtasks_path(@integration), params: body, headers: signed_headers(body, timestamp: stale)
      end
      assert_response :ok
    end

    test 'still rejects bad signature when timestamp verification is disabled' do
      @integration.update!(verify_webhook_timestamp: false)
      body = envelope(event: 'link.created', delivery_id: SecureRandom.uuid)
      headers = signed_headers(body, secret: 'wrong-secret')
      post webhooks_mtasks_path(@integration), params: body, headers: headers
      assert_response :unauthorized
    end

    test 'idempotent: same delivery_id only persists once' do
      delivery_id = SecureRandom.uuid
      body = envelope(event: 'link.created', delivery_id: delivery_id)

      assert_difference 'WebhookDelivery.count', 1 do
        2.times do
          post webhooks_mtasks_path(@integration), params: body,
                                                   headers: signed_headers(body, delivery_id: delivery_id)
        end
      end
      assert_response :ok
    end

    test '400 when delivery_id missing from headers and body' do
      body = { version: 1, event: 'link.created', data: {} }.to_json
      headers = signed_headers(body, delivery_id: '').except('X-Mtasks-Delivery')

      post webhooks_mtasks_path(@integration), params: body, headers: headers
      assert_response :bad_request
    end
  end
end
