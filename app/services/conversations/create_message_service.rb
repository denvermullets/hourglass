class Conversations::CreateMessageService < Service
  def initialize(conversation:, user:, params:)
    @conversation = conversation
    @user = user
    @params = params
  end

  def call
    attrs = @params.merge(
      body: @params[:body].to_s.strip,
      data: (@params[:data] || {}).merge('format' => 'markdown')
    )

    message = @conversation.messages.create!(
      attrs.merge(user: @user, message_type: :regular)
    )

    message.files.load if message.files.attached?

    notify_thread_reply(message) if message.parent_message_id.present?
    detect_mentions(message)
    @conversation.update_column(:last_message_at, message.created_at)
    mark_author_read(message)

    message
  end

  private

  def detect_mentions(message)
    Mentions::DetectService.call(message: message)
  end

  def notify_thread_reply(message)
    Messages::NotifyThreadReplyService.call(
      message: message, channel: nil, user: @user, conversation: @conversation
    )
  end

  def mark_author_read(message)
    membership = @conversation.conversation_memberships.find_or_create_by!(user: @user)
    membership.update!(last_read_at: message.created_at)
  end
end
