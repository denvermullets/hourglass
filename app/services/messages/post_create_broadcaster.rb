class Messages::PostCreateBroadcaster < Service
  def initialize(channel:, user:, message:)
    @channel = channel
    @user = user
    @message = message
  end

  def call
    @message.files.load if @message.files.attached?
    broadcast_creation
    detect_mentions
    broadcast_unread_indicators
    mark_author_read
    @message
  end

  private

  def broadcast_creation
    if @message.parent_message_id.present?
      broadcast_thread_reply
      broadcast_reply_indicator_update(@message.parent_message)
      notify_thread_reply
    else
      broadcast_date_separator
      broadcast_append
    end
  end

  def broadcast_append
    fresh_message = Message.includes(user: { avatar_attachment: :blob }).find(@message.id)
    previous = @channel.messages.root_messages.not_deleted
                       .where.not(id: @message.id)
                       .order(created_at: :desc)
                       .first

    Turbo::StreamsChannel.broadcast_append_to(
      @channel,
      target: 'messages',
      partial: 'messages/message',
      locals: { message: fresh_message, grouped: grouped_with?(@message, previous), context: :channel }
    )
  end

  def broadcast_thread_reply
    fresh_message = Message.includes(user: { avatar_attachment: :blob }).find(@message.id)
    previous = @message.parent_message.replies.not_deleted
                       .where.not(id: @message.id)
                       .order(created_at: :desc)
                       .first

    Turbo::StreamsChannel.broadcast_append_to(
      "thread_#{@message.parent_message_id}",
      target: 'thread_replies',
      partial: 'threads/reply',
      locals: {
        reply: fresh_message, server: @channel.server,
        channel: @channel, grouped: grouped_with?(@message, previous)
      }
    )
  end

  def grouped_with?(message, previous)
    previous.present? &&
      !previous.deleted? &&
      previous.user_id == message.user_id &&
      (message.created_at - previous.created_at) <= 60.seconds
  end

  def broadcast_reply_indicator_update(parent_message)
    parent_message.reload
    participant_count = parent_message.thread_participant_count

    Turbo::StreamsChannel.broadcast_replace_to(
      @channel,
      target: "reply_indicator_#{parent_message.id}",
      partial: 'messages/reply_indicator',
      locals: { message: parent_message }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "thread_#{parent_message.id}",
      target: "thread_connector_#{parent_message.id}",
      partial: 'threads/connector',
      locals: { parent_message: parent_message }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "thread_#{parent_message.id}",
      target: "thread_header_meta_#{parent_message.id}",
      partial: 'threads/header_meta',
      locals: { parent_message: parent_message, participant_count: participant_count }
    )
  end

  def detect_mentions
    Mentions::DetectService.call(message: @message)
  end

  def notify_thread_reply
    Messages::NotifyThreadReplyService.call(message: @message, channel: @channel, user: @user)
  end

  def broadcast_unread_indicators
    @channel.update_column(:last_message_at, @message.created_at)

    notifiable_member_ids.each do |user_id|
      broadcast_unread_to_user(user_id)
    end
  end

  def mark_author_read
    membership = ChannelMembership.find_or_create_by!(user: @user, channel: @channel)
    membership.update!(last_read_at: @message.created_at)
  end

  def notifiable_member_ids
    scope = @channel.is_private? ? @channel.channel_memberships : @channel.server.memberships
    scope.where.not(user_id: @user.id).pluck(:user_id)
  end

  def broadcast_unread_to_user(user_id)
    target_id = "unread_indicator_channel_#{@channel.id}"

    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user_id}_unread",
      target: target_id,
      html: <<~HTML
        <span id="#{target_id}" data-unread="true" class="flex-shrink-0 ml-auto flex items-center">
          <span class="w-1.5 h-1.5 rounded-full bg-granny-smith-apple-400 block"></span>
        </span>
      HTML
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user_id}_unread_title",
      target: 'unread_title_indicator',
      html: unread_title_html(has_unread: true)
    )
  end

  def unread_title_html(has_unread:)
    inner = has_unread ? '<span data-unread="true"></span>' : ''
    "<span id=\"unread_title_indicator\" class=\"hidden\">#{inner}</span>"
  end

  def broadcast_date_separator
    previous = @channel.messages.not_deleted
                       .where('created_at < ?', @message.created_at)
                       .order(created_at: :desc)
                       .pick(:created_at)

    return if previous&.to_date == @message.created_at.to_date

    Turbo::StreamsChannel.broadcast_append_to(
      @channel,
      target: 'messages',
      partial: 'messages/date_separator',
      locals: { date: @message.created_at }
    )
  end
end
