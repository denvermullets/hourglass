class Messages::CreateService < Service
  def initialize(channel:, user:, params:)
    @channel = channel
    @user = user
    @params = params
  end

  def call
    sanitized_params = @params.merge(
      body: Messages::SanitizeService.call(html: @params[:body])
    )

    message = @channel.messages.create!(
      sanitized_params.merge(user: @user, message_type: :regular)
    )

    broadcast_date_separator(message)
    broadcast_append(message)

    message
  end

  private

  def broadcast_append(message)
    Turbo::StreamsChannel.broadcast_append_to(
      @channel,
      target: 'messages',
      partial: 'messages/message',
      locals: { message: message }
    )
  end

  def broadcast_date_separator(message)
    previous = @channel.messages.not_deleted
                       .where('created_at < ?', message.created_at)
                       .order(created_at: :desc)
                       .pick(:created_at)

    return if previous&.to_date == message.created_at.to_date

    Turbo::StreamsChannel.broadcast_append_to(
      @channel,
      target: 'messages',
      partial: 'messages/date_separator',
      locals: { date: message.created_at.to_date }
    )
  end
end
