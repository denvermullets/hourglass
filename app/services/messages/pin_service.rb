class Messages::PinService < Service
  include Messages::MtasksEmittable

  def initialize(message:, user:)
    @message = message
    @user = user
  end

  def call
    @message.pin!(@user)
    broadcast_message_replace
    broadcast_pinned_count
    emit_outbound
    @message
  end

  private

  def emit_outbound
    return unless emittable?(@message)
    return if @message.parent_message_id.blank?

    link = MtasksLink.issue_threads.find_by(thread_id: @message.parent_message_id)
    return unless link

    enqueue_create(@message, link)
  end

  def stream_target
    @message.in_conversation? ? @message.conversation : @message.channel
  end

  def context
    @message.in_conversation? ? :conversation : :channel
  end

  def broadcast_message_replace
    if @message.parent_message_id.present?
      broadcast_thread_replace
    else
      broadcast_main_replace
    end
  end

  def broadcast_main_replace
    Turbo::StreamsChannel.broadcast_replace_to(
      stream_target,
      target: @message,
      partial: 'messages/message',
      locals: { message: @message, context: context }
    )
  end

  def broadcast_thread_replace
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

    # Also reflect in the channel view (the underlying root has no change, but
    # the parent's pinned state on a thread reply doesn't propagate to root).
  end

  def broadcast_pinned_count
    return if @message.in_conversation? # conversation pinned-counts UI is not in scope

    channel = @message.channel
    Turbo::StreamsChannel.broadcast_replace_to(
      channel,
      target: "channel_#{channel.id}_pinned_count",
      partial: 'channels/pinned_count',
      locals: { server: channel.server, channel: channel }
    )
  end
end
