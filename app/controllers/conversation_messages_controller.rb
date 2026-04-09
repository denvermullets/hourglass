class ConversationMessagesController < ApplicationController
  layout 'app'

  before_action :set_conversation
  before_action :require_conversation_membership!
  before_action :set_message, only: %i[show edit update destroy]
  before_action :require_author!, only: %i[edit update destroy]

  def index
    scope = @conversation.messages.root_messages.not_deleted.includes(:user, files_attachments: :blob)
    scope = scope.where('created_at < ?', Time.zone.parse(params[:before])) if params[:before]
    messages = scope.order(created_at: :desc).limit(51)
    @has_older = messages.size > 50
    @messages = messages.first(50).reverse

    render layout: false
  end

  def show
    render turbo_stream: turbo_stream.replace(
      @message,
      partial: 'messages/message',
      locals: { message: @message, context: :conversation }
    )
  end

  def create
    Conversations::CreateMessageService.call(
      conversation: @conversation,
      user: Current.user,
      params: message_params
    )
    head :ok
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  def edit
    render turbo_stream: turbo_stream.replace(
      @message,
      partial: 'messages/edit_form',
      locals: { message: @message, conversation: @conversation, context: :conversation }
    )
  end

  def update
    Messages::UpdateService.call(message: @message, params: message_params)
    head :ok
  rescue ActiveRecord::RecordInvalid
    render turbo_stream: turbo_stream.replace(
      @message,
      partial: 'messages/edit_form',
      locals: { message: @message, conversation: @conversation, context: :conversation }
    )
  end

  def destroy
    Messages::DeleteService.call(message: @message)
    head :ok
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end

  def require_conversation_membership!
    return if @conversation.conversation_memberships.exists?(user: Current.user)

    head :forbidden
  end

  def set_message
    @message = @conversation.messages.find(params[:id])
  end

  def require_author!
    return if @message.owned_by?(Current.user)

    head :forbidden
  end

  def message_params
    params.require(:message).permit(:body, :parent_message_id, files: [], purge_file_ids: [])
  end
end
