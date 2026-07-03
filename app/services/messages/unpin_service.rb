class Messages::UnpinService < Service
  include Messages::MtasksEmittable

  def initialize(message:)
    @message = message
  end

  def call
    @message.unpin!
    emit_outbound
    @message
  end

  private

  def emit_outbound
    return unless emittable?(@message)
    return if @message.data['mtasks_decision_id'].blank?

    enqueue_unpinned(@message)
  end
end
