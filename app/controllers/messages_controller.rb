class MessagesController < ApplicationController
  include Authorization
  include Messages::EchoResponses

  layout 'app'

  before_action :set_server
  before_action :set_channel
  before_action :require_membership!
  before_action :set_message, only: %i[show edit update destroy pin unpin move]
  before_action :require_author!, only: %i[edit update destroy]
  before_action :require_move_permission!, only: :move

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
    @message = Messages::CreateService.call(
      channel: @channel,
      user: Current.user,
      params: message_params
    )

    if @message&.persisted?
      render turbo_stream: created_message_streams(@message, context: :channel, server: @server, channel: @channel)
    else
      head :ok
    end
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
    render turbo_stream: updated_message_streams(@message, context: :channel, server: @server, channel: @channel)
  rescue ActiveRecord::RecordInvalid
    render turbo_stream: turbo_stream.replace(
      @message,
      partial: 'messages/edit_form',
      locals: { message: @message, server: @server, channel: @channel }
    )
  end

  def destroy
    Messages::DeleteService.call(message: @message)
    render turbo_stream: deleted_message_streams(@message, context: :channel, server: @server, channel: @channel)
  end

  def pin
    Messages::PinService.call(message: @message, user: Current.user) unless @message.pinned?
    render turbo_stream: pinned_message_streams(@message)
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  def unpin
    Messages::UnpinService.call(message: @message) if @message.pinned?
    render turbo_stream: pinned_message_streams(@message)
  end

  def move
    if @message.parent_message_id.present?
      redirect_to(server_channel_path(@server, @channel), alert: 'Only top-level messages can be moved.') and return
    end

    target = @server.channels.active.find(params[:target_channel_id])
    Messages::MoveService.call(message: @message, target_channel: target)
    redirect_to server_channel_path(@server, target)
  rescue ActiveRecord::RecordNotFound
    redirect_to server_channel_path(@server, @channel), alert: 'That channel is unavailable.'
  end

  private

  # Pin/unpin repaints the message itself (pinned chrome + the pin/unpin link label) and
  # the channel header's pinned count. The count target only exists on channels#show, so
  # pinning a reply from the thread page just no-ops that stream.
  def pinned_message_streams(message)
    updated_message_streams(message, context: :channel, server: @server, channel: @channel) +
      [turbo_stream.replace("channel_#{@channel.id}_pinned_count",
                            partial: 'channels/pinned_count',
                            locals: { server: @server, channel: @channel })]
  end

  def require_move_permission!
    return if current_membership&.can_move_messages?

    head :forbidden
  end

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
