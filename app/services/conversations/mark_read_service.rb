class Conversations::MarkReadService < Service
  def initialize(conversation:, user:)
    @conversation = conversation
    @user = user
  end

  def call
    membership = ConversationMembership.find_or_create_by!(
      user: @user,
      conversation: @conversation
    )
    membership.mark_read!

    broadcast_read_indicator
    membership
  end

  private

  def broadcast_read_indicator
    target_id = "unread_indicator_conversation_#{@conversation.id}"
    classes = 'flex-shrink-0 ml-auto flex items-center'

    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{@user.id}_unread",
      target: target_id,
      html: "<span id=\"#{target_id}\" class=\"#{classes}\"></span>"
    )

    broadcast_title_indicator
  end

  def broadcast_title_indicator
    has_unread = any_unread?
    inner = has_unread ? '<span data-unread="true"></span>' : ''
    html = "<span id=\"unread_title_indicator\" class=\"hidden\">#{inner}</span>"

    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{@user.id}_unread_title",
      target: 'unread_title_indicator',
      html: html
    )
  end

  def any_unread?
    @user.unread_channels? || @user.unread_conversations?
  end
end
