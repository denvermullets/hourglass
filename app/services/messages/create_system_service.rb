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

      @channel.update_column(:last_message_at, message.created_at)
      message
    end

    private

    def fallback_user
      @channel.server.owner
    end
  end
end
