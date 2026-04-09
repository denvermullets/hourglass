class Messages::NotifyThreadReplyService < Service
  def initialize(message:, user:, channel: nil, conversation: nil)
    @message = message
    @channel = channel
    @conversation = conversation
    @user = user
  end

  def call
    recipient_ids = thread_recipient_ids
    return if recipient_ids.empty?

    data = notification_data

    User.where(id: recipient_ids).find_each do |recipient|
      Notifications::CreateService.call(
        user: recipient, actor: @user,
        notification_type: :reply, notifiable: @message, data: data
      )
    end
  end

  private

  def thread_recipient_ids
    parent = @message.parent_message
    ids = parent.replies.not_deleted.where.not(user_id: @user.id).distinct.pluck(:user_id)
    ids << parent.user_id unless parent.user_id == @user.id
    ids.uniq
  end

  def notification_data
    preview = ActionController::Base.helpers.strip_tags(@message.body).to_s.truncate(100)

    if @conversation
      {
        'conversation_id' => @conversation.id,
        'conversation_name' => @conversation.display_name(@user),
        'message_id' => @message.id,
        'parent_message_id' => @message.parent_message_id,
        'preview' => preview
      }
    else
      {
        'channel_name' => @channel.name, 'server_name' => @channel.server.name,
        'server_id' => @channel.server_id, 'channel_id' => @channel.id,
        'message_id' => @message.id, 'parent_message_id' => @message.parent_message_id,
        'preview' => preview
      }
    end
  end
end
