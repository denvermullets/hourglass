module Api
  module V1
    class MessageSerializer
      def initialize(message)
        @message = message
      end

      def as_json(*)
        {
          id: @message.id,
          channel_id: @message.channel_id,
          parent_message_id: @message.parent_message_id,
          user_id: @message.user_id,
          body: @message.body,
          edited_at: @message.edited_at,
          replies_count: @message.replies_count,
          created_at: @message.created_at.iso8601,
          updated_at: @message.updated_at.iso8601
        }
      end
    end
  end
end
