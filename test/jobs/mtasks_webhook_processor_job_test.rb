require 'test_helper'

class MtasksWebhookProcessorJobTest < ActiveJob::TestCase
  setup do
    @delivery = WebhookDelivery.create!(
      source: WebhookDelivery::SOURCE_MTASKS,
      delivery_id: SecureRandom.uuid,
      event_type: 'link.created',
      received_at: Time.current,
      payload: { 'event' => 'link.created', 'data' => { 'link_type' => 'project_channel' } }
    )
  end

  test 'marks delivery processed for known event' do
    MtasksWebhookProcessorJob.perform_now(@delivery.id)
    assert @delivery.reload.processed?
  end

  test 'no-op when delivery is already processed' do
    @delivery.update!(processed_at: 1.minute.ago)
    original_processed_at = @delivery.processed_at
    MtasksWebhookProcessorJob.perform_now(@delivery.id)
    assert_equal original_processed_at.to_i, @delivery.reload.processed_at.to_i
  end

  test 'still marks processed for unknown event types (logs warning)' do
    @delivery.update!(event_type: 'totally.unknown')
    MtasksWebhookProcessorJob.perform_now(@delivery.id)
    assert @delivery.reload.processed?
  end

  test 'each documented event type has a registered handler' do
    %w[link.created link.removed issue.created issue.updated issue.status_changed issue.assigned].each do |event|
      assert MtasksWebhookProcessorJob::HANDLERS.key?(event), "expected handler for #{event}"
    end
  end
end
