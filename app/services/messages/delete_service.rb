class Messages::DeleteService < Service
  def initialize(message:)
    @message = message
  end

  def call
    @message.update!(deleted_at: Time.current)
    @message.files.purge_later if @message.files.attached?

    @message.parent_message_id.present? ? broadcast_thread_delete : broadcast_main_delete

    @message
  end

  private

  def stream_target
    @message.in_conversation? ? @message.conversation : @message.channel
  end

  def context
    @message.in_conversation? ? :conversation : :channel
  end

  def broadcast_thread_delete
    thread_locals = { reply: @message, context: context }
    if @message.in_conversation?
      thread_locals[:conversation] = @message.conversation
    else
      thread_locals[:server] = @message.channel.server
      thread_locals[:channel] = @message.channel
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      "thread_#{@message.parent_message_id}",
      target: @message,
      partial: 'threads/reply',
      locals: thread_locals
    )

    parent = @message.parent_message.reload
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_target,
      target: "reply_indicator_#{parent.id}",
      partial: 'messages/reply_indicator',
      locals: { message: parent, context: context }
    )
  end

  def broadcast_main_delete
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_target,
      target: @message,
      partial: 'messages/message',
      locals: { message: @message, context: context }
    )
  end
end
