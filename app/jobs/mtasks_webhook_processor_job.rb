class MtasksWebhookProcessorJob < ApplicationJob
  queue_as :default

  HANDLERS = {
    'link.created' => :handle_link,
    'link.removed' => :handle_link,
    'issue.created' => :handle_issue,
    'issue.updated' => :handle_issue,
    'issue.status_changed' => :handle_issue,
    'issue.assigned' => :handle_issue
  }.freeze

  def perform(delivery_id)
    delivery = WebhookDelivery.find(delivery_id)
    return if delivery.processed?

    handler = HANDLERS[delivery.event_type]
    if handler
      send(handler, delivery)
    else
      Rails.logger.warn("[mtasks-webhook] unknown event: #{delivery.event_type}")
    end

    delivery.update!(processed_at: Time.current)
  end

  private

  def handle_link(delivery)
    result = Webhooks::Mtasks::ProcessLink.call(delivery: delivery)
    return if result.ok

    Rails.logger.warn("[mtasks-webhook] link processing rejected: #{result.error}")
  end

  def handle_issue(delivery)
    result = Webhooks::Mtasks::ProcessIssue.call(delivery: delivery)
    return if result.ok

    Rails.logger.warn("[mtasks-webhook] issue processing rejected: #{result.error}")
  end

  # Auto-define stubs for any remaining stubbed events (skips real handlers).
  HANDLERS.each_value.uniq.reject { |m| %i[handle_link handle_issue].include?(m) }.each do |method_name|
    define_method(method_name) do |delivery|
      Rails.logger.info("[mtasks-webhook] TODO #{method_name}: #{delivery.payload['data'].inspect}")
    end
  end
end
