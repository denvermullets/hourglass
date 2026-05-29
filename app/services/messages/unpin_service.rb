class Messages::UnpinService < Service
  include Messages::MtasksEmittable

  def initialize(message:)
    @message = message
  end

  def call
    @message.unpin!
    broadcast_message_replace
    broadcast_pinned_count
    emit_outbound
    @message
  end

  private

  def emit_outbound
    return unless emittable?(@message)
    return if @message.data['mtasks_decision_id'].blank?

    enqueue_unpinned(@message)
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
  end

  def broadcast_pinned_count
    return if @message.in_conversation?

    channel = @message.channel
    Turbo::StreamsChannel.broadcast_replace_to(
      channel,
      target: "channel_#{channel.id}_pinned_count",
      partial: 'channels/pinned_count',
      locals: { server: channel.server, channel: channel }
    )
  end
end
