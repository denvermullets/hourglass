# Relocates a root message (and every threaded reply) to another channel in the same
# server. Threading is preserved — replies keep their parent_message_id and just follow
# the root's channel_id. Other viewers pick up the change via the polling refresh; the
# actor is redirected to the destination channel by the controller.
class Messages::MoveService < Service
  def initialize(message:, target_channel:)
    @message = message
    @target_channel = target_channel
  end

  def call
    return @message unless @message.parent_message_id.nil?
    return @message if @message.channel_id == @target_channel.id

    source_channel = @message.channel

    Message.transaction do
      ids = [@message.id] + @message.replies.ids
      Message.where(id: ids).update_all(channel_id: @target_channel.id, updated_at: Time.current)
    end

    recompute_last_message_at(source_channel)
    recompute_last_message_at(@target_channel)

    @message.reload
  end

  private

  def recompute_last_message_at(channel)
    last_at = channel.messages.not_deleted.maximum(:created_at)
    channel.update_column(:last_message_at, last_at)
  end
end
