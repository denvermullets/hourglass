require 'test_helper'

class WebhookDeliveryTest < ActiveSupport::TestCase
  test 'requires source, delivery_id, event_type, received_at' do
    delivery = WebhookDelivery.new
    assert_not delivery.valid?
    assert delivery.errors[:source].any?
    assert delivery.errors[:delivery_id].any?
    assert delivery.errors[:event_type].any?
    assert delivery.errors[:received_at].any?
  end

  test 'rejects unknown source' do
    delivery = WebhookDelivery.new(
      source: 'bogus',
      delivery_id: 'dlv_x',
      event_type: 'issue.created',
      received_at: Time.current
    )
    assert_not delivery.valid?
    assert delivery.errors[:source].any?
  end

  test 'rejects duplicate delivery_id within same source' do
    duplicate = WebhookDelivery.new(
      source: 'mtasks',
      delivery_id: webhook_deliveries(:issue_created).delivery_id,
      event_type: 'issue.created',
      received_at: Time.current
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:delivery_id].any?
  end

  test 'unprocessed scope filters to nil processed_at' do
    unprocessed = WebhookDelivery.unprocessed
    assert unprocessed.exists?(id: webhook_deliveries(:issue_created).id)
    assert_not unprocessed.exists?(id: webhook_deliveries(:issue_updated_processed).id)
  end

  test 'processed? reflects processed_at' do
    assert webhook_deliveries(:issue_updated_processed).processed?
    assert_not webhook_deliveries(:issue_created).processed?
  end
end
