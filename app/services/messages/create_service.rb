class Messages::CreateService < Service # rubocop:disable Metrics/ClassLength
  include Messages::MtasksEmittable

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

    broadcast_creation(message)
    detect_mentions(message)
    broadcast_unread_indicators(message)
    mark_author_read(message)
    emit_outbound(message)

    message
  end

  private

  def broadcast_creation(message)
    if message.parent_message_id.present?
      broadcast_thread_reply(message)
      broadcast_reply_indicator_update(message.parent_message)
      notify_thread_reply(message)
    else
      broadcast_date_separator(message)
      broadcast_append(message)
    end
  end

  def emit_outbound(message)
    return unless emittable?(message)

    link = outbound_link_for(message)
    return unless link

    enqueue_create(message, link)
  end

  def outbound_link_for(message)
    if message.parent_message_id.present?
      MtasksLink.issue_threads.find_by(thread_id: message.parent_message_id)
    else
      @channel.mtasks_project_link
    end
  end

  def broadcast_append(message)
    fresh_message = Message.includes(user: { avatar_attachment: :blob }).find(message.id)
    previous = @channel.messages.root_messages.not_deleted
                       .where.not(id: message.id)
                       .order(created_at: :desc)
                       .first

    Turbo::StreamsChannel.broadcast_append_to(
      @channel,
      target: 'messages',
      partial: 'messages/message',
      locals: { message: fresh_message, grouped: grouped_with?(message, previous), context: :channel }
    )
  end

  def broadcast_thread_reply(message)
    fresh_message = Message.includes(user: { avatar_attachment: :blob }).find(message.id)
    previous = message.parent_message.replies.not_deleted
                      .where.not(id: message.id)
                      .order(created_at: :desc)
                      .first

    Turbo::StreamsChannel.broadcast_append_to(
      "thread_#{message.parent_message_id}",
      target: 'thread_replies',
      partial: 'threads/reply',
      locals: {
        reply: fresh_message, server: @channel.server,
        channel: @channel, grouped: grouped_with?(message, previous)
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
    Messages::NotifyThreadReplyService.call(message: message, channel: @channel, user: @user)
  end

  def broadcast_unread_indicators(message)
    @channel.update_column(:last_message_at, message.created_at)

    notifiable_member_ids.each do |user_id|
      broadcast_unread_to_user(user_id)
    end
  end

  def mark_author_read(message)
    membership = ChannelMembership.find_or_create_by!(user: @user, channel: @channel)
    membership.update!(last_read_at: message.created_at)
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
      locals: { date: message.created_at }
    )
  end
end
