module Messages
  class CreateSystemService < Service
    def initialize(channel:, body:, data: {}, parent_message: nil, attributed_user: nil)
      @channel         = channel
      @body            = body
      @data            = data
      @parent_message  = parent_message
      @attributed_user = attributed_user
    end

    def call
      sanitized = Messages::SanitizeService.call(html: @body)
      message = @channel.messages.create!(
        body: sanitized,
        user: @attributed_user || fallback_user,
        message_type: :system,
        parent_message_id: @parent_message&.id,
        data: @data
      )

      if message.parent_message_id.present?
        broadcast_thread_reply(message)
      else
        broadcast_append(message)
      end

      @channel.update_column(:last_message_at, message.created_at)
      message
    end

    private

    def fallback_user
      @channel.server.owner
    end

    def broadcast_append(message)
      fresh = Message.includes(user: { avatar_attachment: :blob }).find(message.id)
      Turbo::StreamsChannel.broadcast_append_to(
        @channel,
        target: 'messages',
        partial: 'messages/message',
        locals: { message: fresh, grouped: false, context: :channel }
      )
    end

    def broadcast_thread_reply(message)
      fresh = Message.includes(user: { avatar_attachment: :blob }).find(message.id)
      Turbo::StreamsChannel.broadcast_append_to(
        "thread_#{message.parent_message_id}",
        target: 'thread_replies',
        partial: 'threads/reply',
        locals: {
          reply: fresh,
          grouped: false,
          server: @channel.server,
          channel: @channel,
          context: :channel
        }
      )
    end
  end
end
