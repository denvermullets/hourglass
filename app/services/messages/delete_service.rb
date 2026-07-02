class Messages::DeleteService < Service
  include Messages::MtasksEmittable

  def initialize(message:)
    @message = message
  end

  def call
    @message.update!(deleted_at: Time.current)
    @message.files.purge_later if @message.files.attached?

    emit_outbound

    @message
  end

  private

  def emit_outbound
    return unless emittable?(@message)
    return if @message.data['mtasks_comment_id'].blank?

    enqueue_delete(@message)
  end
end
