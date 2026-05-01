require 'net/http'
require 'openssl'
require 'securerandom'
require 'uri'

module Webhooks
  class MtasksTestDispatcher < Service
    Result = Struct.new(:ok, :status, :delivery, :error, keyword_init: true)

    def initialize(integration:, event_type:, payload_data:, host:)
      @integration  = integration
      @event_type   = event_type
      @payload_data = payload_data
      @host         = host
    end

    def call
      delivery_id = SecureRandom.uuid
      body = build_body(delivery_id)
      response = send_request(body, delivery_id)

      Result.new(
        ok: response.code.to_i == 200,
        status: response.code.to_i,
        delivery: WebhookDelivery.find_by(source: WebhookDelivery::SOURCE_MTASKS, delivery_id: delivery_id)
      )
    rescue StandardError => e
      Result.new(ok: false, status: 0, delivery: nil, error: e.message)
    end

    private

    def build_body(delivery_id)
      {
        version: 1,
        event: @event_type,
        delivery_id: delivery_id,
        data: @payload_data
      }.to_json
    end

    def send_request(body, delivery_id)
      uri = URI.parse(@integration.webhook_url(host: @host))
      req = build_request(uri, body, delivery_id)

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 5) do |http|
        http.request(req)
      end
    end

    def build_request(uri, body, delivery_id)
      signature = "sha256=#{OpenSSL::HMAC.hexdigest('sha256', @integration.webhook_secret.to_s, body)}"
      req = Net::HTTP::Post.new(uri)
      req['Content-Type']           = 'application/json'
      req['X-Mtasks-Event']         = @event_type
      req['X-Mtasks-Delivery']      = delivery_id
      req['X-Mtasks-Timestamp']     = Time.current.to_i.to_s
      req['X-Mtasks-Signature-256'] = signature
      req.body = body
      req
    end
  end
end
