module Api
  module V1
    class ChannelSerializer
      def initialize(channel)
        @channel = channel
      end

      def as_json(*)
        {
          id: @channel.id,
          server_id: @channel.server_id,
          name: @channel.name,
          description: @channel.description,
          topic: @channel.topic,
          is_private: @channel.is_private,
          channel_type: @channel.channel_type,
          archived_at: @channel.archived_at
        }
      end
    end
  end
end
