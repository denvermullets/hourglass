# Runs the post-create side effects for a new message: thread-reply notification, mention
# detection, the channel last_message_at bump, and marking the author read. (Broadcasts
# were removed in Phase 3 of the polling migration — the UI now refreshes via poll+morph.
# Name kept to avoid churning its many call sites.)
class Messages::PostCreateBroadcaster < Service
  def initialize(channel:, user:, message:)
    @channel = channel
    @user = user
    @message = message
  end

  def call
    @message.files.load if @message.files.attached?
    notify_thread_reply if @message.parent_message_id.present?
    detect_mentions
    @channel.update_column(:last_message_at, @message.created_at)
    mark_author_read
    @message
  end

  private

  def detect_mentions
    Mentions::DetectService.call(message: @message)
  end

  def notify_thread_reply
    Messages::NotifyThreadReplyService.call(message: @message, channel: @channel, user: @user)
  end

  def mark_author_read
    membership = ChannelMembership.find_or_create_by!(user: @user, channel: @channel)
    membership.update!(last_read_at: @message.created_at)
  end
end
