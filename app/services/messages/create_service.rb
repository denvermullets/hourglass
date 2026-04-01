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
      notify_thread_reply(message)
    else
      broadcast_date_separator(message)
      broadcast_append(message)
    end

    detect_mentions(message)

    message
  end

  private

  def broadcast_append(message)
    fresh_message = Message.includes(user: { avatar_attachment: :blob }).find(message.id)
    Turbo::StreamsChannel.broadcast_append_to(
      @channel,
      target: 'messages',
      partial: 'messages/message',
      locals: { message: fresh_message }
    )
  end

  def broadcast_thread_reply(message)
    fresh_message = Message.includes(user: { avatar_attachment: :blob }).find(message.id)
    Turbo::StreamsChannel.broadcast_append_to(
      "thread_#{message.parent_message_id}",
      target: 'thread_replies',
      partial: 'threads/reply',
      locals: { reply: fresh_message, server: @channel.server, channel: @channel }
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

  def detect_mentions(message)
    Mentions::DetectService.call(message: message)
  end

  def notify_thread_reply(message)
    parent_author = message.parent_message.user
    return if parent_author == @user

    preview = ActionController::Base.helpers.strip_tags(message.body).to_s.truncate(100)

    Notifications::CreateService.call(
      user: parent_author,
      actor: @user,
      notification_type: :reply,
      notifiable: message,
      data: {
        'channel_name' => @channel.name,
        'server_name' => @channel.server.name,
        'server_id' => @channel.server_id,
        'channel_id' => @channel.id,
        'message_id' => message.id,
        'preview' => preview
      }
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
