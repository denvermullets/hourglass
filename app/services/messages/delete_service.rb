class Messages::DeleteService < Service
  def initialize(message:)
    @message = message
  end

  def call
    @message.update!(deleted_at: Time.current)

    Turbo::StreamsChannel.broadcast_replace_to(
      @message.channel,
      target: @message,
      partial: 'messages/message',
      locals: { message: @message }
    )

    @message
  end
end
