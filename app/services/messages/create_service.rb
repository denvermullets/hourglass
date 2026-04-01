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

    # Eager load attachments before broadcasting to avoid N+1
    message.files.load if message.files.attached?

    if message.parent_message_id.present?
      broadcast_thread_reply(message)
      broadcast_reply_indicator_update(message.parent_message)
    else
      broadcast_date_separator(message)
      broadcast_append(message)
    end

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

  def broadcast_thread_reply(message)
    Turbo::StreamsChannel.broadcast_append_to(
      "thread_#{message.parent_message_id}",
      target: 'thread_replies',
      partial: 'threads/reply',
      locals: { reply: message, server: @channel.server, channel: @channel }
    )
  end

  def broadcast_reply_indicator_update(parent_message)
    parent_message.reload
    participant_count = parent_message.thread_participant_count

    # Update reply indicator in main channel view
    Turbo::StreamsChannel.broadcast_replace_to(
      @channel,
      target: "reply_indicator_#{parent_message.id}",
      partial: 'messages/reply_indicator',
      locals: { message: parent_message }
    )

    # Update connector count in thread view
    Turbo::StreamsChannel.broadcast_replace_to(
      "thread_#{parent_message.id}",
      target: "thread_connector_#{parent_message.id}",
      partial: 'threads/connector',
      locals: { parent_message: parent_message }
    )

    # Update header meta in thread view
    Turbo::StreamsChannel.broadcast_replace_to(
      "thread_#{parent_message.id}",
      target: "thread_header_meta_#{parent_message.id}",
      partial: 'threads/header_meta',
      locals: { parent_message: parent_message, participant_count: participant_count }
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
