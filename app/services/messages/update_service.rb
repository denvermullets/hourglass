class Messages::UpdateService < Service
  def initialize(message:, params:)
    @message = message
    @params = params
  end

  def call
    sanitized_params = @params.merge(
      body: Messages::SanitizeService.call(html: @params[:body])
    )

    @message.update!(sanitized_params.merge(edited_at: Time.current))

    if @message.parent_message_id.present?
      Turbo::StreamsChannel.broadcast_replace_to(
        "thread_#{@message.parent_message_id}",
        target: @message,
        partial: 'threads/reply',
        locals: { reply: @message, server: @message.channel.server, channel: @message.channel }
      )
    else
      Turbo::StreamsChannel.broadcast_replace_to(
        @message.channel,
        target: @message,
        partial: 'messages/message',
        locals: { message: @message }
      )
    end

    @message
  end
end
