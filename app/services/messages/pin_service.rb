class Messages::PinService < Service
  include Messages::MtasksEmittable

  def initialize(message:, user:)
    @message = message
    @user = user
  end

  def call
    @message.pin!(@user)
    emit_outbound
    @message
  end

  private

  def emit_outbound
    return unless emittable?(@message)

    link = pin_target_link
    return unless link

    enqueue_pinned(@message, link)
  end

  def pin_target_link
    if @message.parent_message_id.present?
      MtasksLink.issue_threads.find_by(thread_id: @message.parent_message_id)
    else
      @message.channel&.mtasks_project_link
    end
  end
end
