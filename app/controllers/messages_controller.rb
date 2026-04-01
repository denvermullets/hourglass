class MessagesController < ApplicationController
  include Authorization

  layout 'app'

  before_action :set_server
  before_action :set_channel
  before_action :require_membership!
  before_action :set_message, only: %i[show edit update destroy]
  before_action :require_author!, only: %i[edit update destroy]

  def index
    scope = @channel.messages.root_messages.not_deleted.includes(:user, files_attachments: :blob)
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
      locals: { message: @message }
    )
  end

  def create
    Messages::CreateService.call(
      channel: @channel,
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
      locals: { message: @message, server: @server, channel: @channel }
    )
  end

  def update
    Messages::UpdateService.call(message: @message, params: message_params)
    head :ok
  rescue ActiveRecord::RecordInvalid
    render turbo_stream: turbo_stream.replace(
      @message,
      partial: 'messages/edit_form',
      locals: { message: @message, server: @server, channel: @channel }
    )
  end

  def destroy
    Messages::DeleteService.call(message: @message)
    head :ok
  end

  private

  def set_server
    @server = Server.find(params[:server_id])
  end

  def set_channel
    @channel = @server.channels.find(params[:channel_id])
  end

  def set_message
    @message = @channel.messages.find(params[:id])
  end

  def require_author!
    return if @message.owned_by?(Current.user)

    head :forbidden
  end

  def message_params
    params.require(:message).permit(:body, :parent_message_id, files: [], purge_file_ids: [])
  end
end
