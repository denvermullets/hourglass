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

    Turbo::StreamsChannel.broadcast_replace_to(
      @message.channel,
      target: @message,
      partial: 'messages/message',
      locals: { message: @message }
    )

    @message
  end
end
