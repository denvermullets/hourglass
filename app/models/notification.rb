class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: 'User'
  belongs_to :notifiable, polymorphic: true

  enum :notification_type, {
    mention: 0,
    reply: 1,
    reaction: 2,
    channel_invite: 3,
    dm: 4,
    system: 5
  }

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :feed, -> { recent.limit(50) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end
end
