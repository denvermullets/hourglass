class Messages::DeleteService < Service
  def initialize(message:)
    @message = message
  end

  def call
    @message.update!(deleted_at: Time.current)

    @message.parent_message_id.present? ? broadcast_thread_delete : broadcast_channel_delete

    @message
  end

  private

  def broadcast_thread_delete
    Turbo::StreamsChannel.broadcast_replace_to(
      "thread_#{@message.parent_message_id}",
      target: @message,
      partial: 'threads/reply',
      locals: { reply: @message, server: @message.channel.server, channel: @message.channel }
    )

    parent = @message.parent_message.reload
    Turbo::StreamsChannel.broadcast_replace_to(
      @message.channel,
      target: "reply_indicator_#{parent.id}",
      partial: 'messages/reply_indicator',
      locals: { message: parent }
    )
  end

  def broadcast_channel_delete
    Turbo::StreamsChannel.broadcast_replace_to(
      @message.channel,
      target: @message,
      partial: 'messages/message',
      locals: { message: @message }
    )
  end
end
