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

  test 'link.created routes through Webhooks::Mtasks::ProcessLink' do
    captured = []
    fake_result = Struct.new(:ok, :error, keyword_init: true).new(ok: true)
    Webhooks::Mtasks::ProcessLink.singleton_class.alias_method(:_orig_call, :call)
    Webhooks::Mtasks::ProcessLink.define_singleton_method(:call) do |**kwargs|
      captured << kwargs[:delivery]
      fake_result
    end

    MtasksWebhookProcessorJob.perform_now(@delivery.id)
    assert_equal [@delivery.id], captured.map(&:id)
    assert @delivery.reload.processed?
  ensure
    Webhooks::Mtasks::ProcessLink.singleton_class.alias_method(:call, :_orig_call)
    Webhooks::Mtasks::ProcessLink.singleton_class.send(:remove_method, :_orig_call)
  end

  test 'delivery is still marked processed when ProcessLink returns an error result' do
    fake_result = Struct.new(:ok, :error, keyword_init: true).new(ok: false, error: 'something blew up')
    Webhooks::Mtasks::ProcessLink.singleton_class.alias_method(:_orig_call, :call)
    Webhooks::Mtasks::ProcessLink.define_singleton_method(:call) { |**| fake_result }

    MtasksWebhookProcessorJob.perform_now(@delivery.id)
    assert @delivery.reload.processed?
  ensure
    Webhooks::Mtasks::ProcessLink.singleton_class.alias_method(:call, :_orig_call)
    Webhooks::Mtasks::ProcessLink.singleton_class.send(:remove_method, :_orig_call)
  end

  test 'issue.created routes through Webhooks::Mtasks::ProcessIssue' do
    @delivery.update!(event_type: 'issue.created',
                      payload: { 'event' => 'issue.created', 'data' => { 'issue_id' => 91 } })

    captured = []
    fake_result = Struct.new(:ok, :error, keyword_init: true).new(ok: true)
    Webhooks::Mtasks::ProcessIssue.singleton_class.alias_method(:_orig_call, :call)
    Webhooks::Mtasks::ProcessIssue.define_singleton_method(:call) do |**kwargs|
      captured << kwargs[:delivery]
      fake_result
    end

    MtasksWebhookProcessorJob.perform_now(@delivery.id)
    assert_equal [@delivery.id], captured.map(&:id)
    assert @delivery.reload.processed?
  ensure
    Webhooks::Mtasks::ProcessIssue.singleton_class.alias_method(:call, :_orig_call)
    Webhooks::Mtasks::ProcessIssue.singleton_class.send(:remove_method, :_orig_call)
  end
end
