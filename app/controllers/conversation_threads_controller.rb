class ConversationThreadsController < ApplicationController
  layout 'app'

  before_action :set_conversation
  before_action :require_conversation_membership!
  before_action :set_parent_message

  def show
    @conversations = Current.user.conversations.ordered
                            .includes(:members, :conversation_memberships)
    @replies = @parent_message.replies.not_deleted.includes(:user).ordered
    @participant_count = @parent_message.thread_participant_count
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  def require_conversation_membership!
    return if @conversation.conversation_memberships.exists?(user: Current.user)

    redirect_to conversations_path, alert: 'You are not a member of this conversation.'
  end

  def set_parent_message
    @parent_message = @conversation.messages.find(params[:message_id])
  end
end
