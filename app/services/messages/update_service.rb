class Messages::UpdateService < Service
  include Messages::MtasksEmittable

  def initialize(message:, params:)
    @message = message
    @params = params
  end

  def call
    purge_removed_files
    update_message
    broadcast_update
    emit_outbound

    @message
  end

  private

  def emit_outbound
    return unless emittable?(@message)
    return if @message.data['mtasks_comment_id'].blank?

    enqueue_update(@message)
  end

  def purge_removed_files
    purge_file_ids = @params.delete(:purge_file_ids)
    @message.files.where(id: purge_file_ids).each(&:purge_later) if purge_file_ids.present?
  end

  def update_message
    sanitized_params = @params.merge(
      body: Messages::SanitizeService.call(html: @params[:body])
    )

    @message.update!(sanitized_params.merge(edited_at: Time.current))
    @message.files.load if @message.files.attached?
  end

  def broadcast_update
    @message.parent_message_id.present? ? broadcast_thread_update : broadcast_main_update
  end

  def broadcast_thread_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "thread_#{@message.parent_message_id}",
      target: @message,
      partial: 'threads/reply',
      locals: thread_locals
    )
  end

  def broadcast_main_update
    Turbo::StreamsChannel.broadcast_replace_to(
      @message.messageable,
      target: @message,
      partial: 'messages/message',
      locals: { message: @message, context: broadcast_context }
    )
  end

  def thread_locals
    base = { reply: @message, context: broadcast_context }
    if @message.in_conversation?
      base.merge(conversation: @message.conversation)
    else
      base.merge(server: @message.channel.server, channel: @message.channel)
    end
  end

  def broadcast_context
    @message.in_conversation? ? :conversation : :channel
  end
end
