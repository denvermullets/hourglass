class Message < ApplicationRecord
  belongs_to :user
  belongs_to :channel, optional: true
  belongs_to :conversation, optional: true
  belongs_to :parent_message, class_name: 'Message', optional: true, counter_cache: :replies_count
  has_many :replies, class_name: 'Message', foreign_key: :parent_message_id, dependent: :nullify
  has_many :notifications, as: :notifiable, dependent: :destroy

  has_many_attached :files

  enum :message_type, { regular: 0, system: 1, user_join: 2, user_leave: 3 }

  validates :body, length: { maximum: 20_000 }
  validate :body_or_files_present
  validate :body_text_length
  validate :validate_file_limits
  validate :channel_or_conversation_present

  scope :ordered, -> { order(created_at: :asc) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :root_messages, -> { where(parent_message_id: nil) }

  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/png image/gif image/webp
    video/mp4 video/webm video/quicktime
    application/pdf
    application/zip
    audio/mpeg audio/wav audio/ogg
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    text/plain text/markdown
  ].freeze

  def deleted?
    deleted_at.present?
  end

  def edited?
    edited_at.present?
  end

  def owned_by?(user)
    user_id == user.id
  end

  def messageable
    channel || conversation
  end

  def in_conversation?
    conversation_id.present?
  end

  def thread_participant_count
    replies.not_deleted.select(:user_id).distinct.count
  end

  def image_attachments
    files.select { |f| f.content_type.start_with?('image/') }
  end

  def video_attachments
    files.select { |f| f.content_type.start_with?('video/') }
  end

  def file_attachments
    files.reject { |f| f.content_type.start_with?('image/', 'video/') }
  end

  private

  def body_or_files_present
    return if body.present? || files.attached?

    errors.add(:base, 'must have a message body or attachments')
  end

  def body_text_length
    return if body.blank?

    stripped = ActionController::Base.helpers.strip_tags(body).to_s.strip
    return unless stripped.length > 8000

    errors.add(:body, 'is too long (maximum is 8000 characters)')
  end

  def channel_or_conversation_present
    return if channel_id.present? || conversation_id.present?
    return if parent_message_id.present?

    errors.add(:base, 'must belong to a channel or conversation')
  end

  def validate_file_limits
    return unless files.attached?

    errors.add(:files, 'too many attachments (maximum is 10)') if files.size > 10

    files.each do |file|
      errors.add(:files, "#{file.filename} is too large (maximum is 50MB)") if file.byte_size > 50.megabytes
      unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
        errors.add(:files, "#{file.filename} has an unsupported file type")
      end
    end
  end
end
