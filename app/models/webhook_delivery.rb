class WebhookDelivery < ApplicationRecord
  SOURCE_MTASKS = 'mtasks'.freeze
  SOURCES = [SOURCE_MTASKS].freeze

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :delivery_id, presence: true, uniqueness: { scope: :source }
  validates :event_type, presence: true
  validates :received_at, presence: true

  scope :unprocessed, -> { where(processed_at: nil) }
  scope :for_source, ->(source) { where(source: source) }

  def processed?
    processed_at.present?
  end
end
