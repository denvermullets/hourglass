class MtasksOutboundEmitterJob < ApplicationJob
  queue_as :default

  SUPPORTED_EVENTS = %w[link.created link.removed].freeze

  def perform(integration_id:, event_type:, data:)
    unless SUPPORTED_EVENTS.include?(event_type)
      Rails.logger.warn("[mtasks-outbound] unsupported event #{event_type}")
      return
    end

    Rails.logger.info("[mtasks-outbound] TODO emit #{event_type} for integration=#{integration_id}: #{data.inspect}")
  end
end
