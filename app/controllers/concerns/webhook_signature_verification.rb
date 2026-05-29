require 'openssl'

module WebhookSignatureVerification
  extend ActiveSupport::Concern

  REPLAY_WINDOW = 5.minutes

  private

  def verify_webhook_signature!(secret:, signature_header:, body:)
    return render_webhook_unauthorized('missing signature') if signature_header.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, body)}"
    return if Rack::Utils.secure_compare(signature_header, expected)

    render_webhook_unauthorized('invalid signature')
  end

  def verify_webhook_timestamp!(timestamp_header:)
    return render_webhook_unauthorized('missing timestamp') if timestamp_header.blank?

    ts = timestamp_header.to_i
    return render_webhook_unauthorized('invalid timestamp') if ts.zero?
    return if (Time.current.to_i - ts).abs <= REPLAY_WINDOW.to_i

    render_webhook_unauthorized('timestamp outside replay window')
  end

  def render_webhook_unauthorized(reason)
    Rails.logger.warn("[webhook] rejected: #{reason}")
    render json: { error: 'Unauthorized', message: reason }, status: :unauthorized
  end
end
