class Message < ApplicationRecord
  belongs_to :user
  belongs_to :channel, optional: true
  belongs_to :parent_message, class_name: 'Message', optional: true
  has_many :replies, class_name: 'Message', foreign_key: :parent_message_id, dependent: :nullify

  enum :message_type, { regular: 0, system: 1, user_join: 2, user_leave: 3 }

  validates :body, presence: true, length: { maximum: 10_000 }
  validate :body_text_length

  scope :ordered, -> { order(created_at: :asc) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  def deleted?
    deleted_at.present?
  end

  def edited?
    edited_at.present?
  end

  def owned_by?(user)
    user_id == user.id
  end

  private

  def body_text_length
    stripped = ActionController::Base.helpers.strip_tags(body).to_s.strip
    return unless stripped.length > 4000

    errors.add(:body, 'is too long (maximum is 4000 characters)')
  end
end
