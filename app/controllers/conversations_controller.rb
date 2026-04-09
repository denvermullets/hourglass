class ConversationsController < ApplicationController
  layout 'app'

  before_action :set_conversation, only: %i[show mark_read]
  before_action :require_conversation_membership!, only: %i[show mark_read]

  def index
    @conversations = Current.user.conversations.ordered
                            .includes(:members, :conversation_memberships)
    @unread_conversation_ids = unread_conversation_ids
  end

  def show
    @conversations = Current.user.conversations.ordered
                            .includes(:members, :conversation_memberships)
    @unread_conversation_ids = unread_conversation_ids

    messages = @conversation.messages.root_messages.not_deleted
                            .includes(:user)
                            .order(created_at: :desc)
                            .limit(51)
    @has_older = messages.size > 50
    @messages = messages.first(50).reverse
    @message_count = @conversation.messages.not_deleted.count
  end

  def new
    @conversations = Current.user.conversations.ordered
                            .includes(:members, :conversation_memberships)
  end

  def create
    user_ids = Array(params[:user_ids]).map(&:to_i).reject(&:zero?)

    if user_ids.empty?
      redirect_to conversations_path, alert: 'Please select at least one user.'
      return
    end

    conversation = Conversations::FindOrCreateService.call(
      creator: Current.user,
      user_ids: user_ids,
      name: params[:name].presence,
      is_group: user_ids.size > 1 || params[:name].present?
    )

    redirect_to conversation_path(conversation)
  end

  def mark_read
    Conversations::MarkReadService.call(conversation: @conversation, user: Current.user)
    render inline: "<%= turbo_frame_tag 'mark_read' %>", layout: false
  end

  def user_search
    query = params[:q].to_s.strip
    if query.length >= 2
      shared_server_ids = Current.user.servers.select(:id)
      @users = User.joins(:memberships)
                   .where(memberships: { server_id: shared_server_ids })
                   .where.not(id: Current.user.id)
                   .where('username LIKE ?', "%#{query}%")
                   .distinct
                   .limit(10)
    else
      @users = User.none
    end

    render layout: false
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def require_conversation_membership!
    return if @conversation.conversation_memberships.exists?(user: Current.user)

    redirect_to conversations_path, alert: 'You are not a member of this conversation.'
  end

  def unread_conversation_ids
    convos = Current.user.conversations
                    .where.not(last_message_at: nil)
                    .pluck(:id, :last_message_at)
                    .to_h

    return Set.new if convos.empty?

    read_times = ConversationMembership
                 .where(user: Current.user, conversation_id: convos.keys)
                 .pluck(:conversation_id, :last_read_at)
                 .to_h

    unread = Set.new
    convos.each do |convo_id, last_msg_at|
      last_read = read_times[convo_id]
      unread.add(convo_id) if last_read.nil? || last_msg_at > last_read
    end
    unread
  end
end
