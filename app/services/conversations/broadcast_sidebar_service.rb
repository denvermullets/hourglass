class Conversations::BroadcastSidebarService < Service
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    @conversation.conversation_memberships.pluck(:user_id).each do |user_id|
      Turbo::StreamsChannel.broadcast_remove_to(
        "user_#{user_id}_conversations",
        target: "conversation_sidebar_item_#{@conversation.id}"
      )

      Turbo::StreamsChannel.broadcast_prepend_to(
        "user_#{user_id}_conversations",
        target: 'conversation_list',
        partial: 'conversations/sidebar_item',
        locals: { conversation: @conversation, current_user: User.find(user_id) }
      )
    end
  end
end
