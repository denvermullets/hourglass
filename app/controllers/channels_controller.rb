class ChannelsController < ApplicationController
  include Authorization

  layout 'app'

  before_action :set_server
  before_action :set_channel, only: %i[show update destroy mark_read reorder archive unarchive move]
  before_action :require_membership!
  before_action :require_moderator!, only: %i[create update destroy reorder archive unarchive move]

  def show
    if @channel.archived?
      redirect_to server_path(@server), alert: 'That channel is archived.'
      return
    end
    @categories = @server.categories.ordered.includes(:channels)
    @unread_channel_ids = unread_channel_ids_for_server(@server)
    messages = @channel.messages.root_messages.not_deleted.includes(:user).order(created_at: :desc).limit(51)
    @has_older = messages.size > 50
    @messages = messages.first(50).reverse
    @message_count = @channel.messages.not_deleted.count
  end

  def mark_read
    Channels::MarkReadService.call(channel: @channel, user: Current.user)
    render inline: "<%= turbo_frame_tag 'mark_read' %>", layout: false
  end

  def create
    @category = @server.categories.find(params[:channel][:category_id])
    @channel = Channels::CreateService.call(
      server: @server,
      category: @category,
      params: channel_params
    )
    redirect_to server_channel_path(@server, @channel)
  rescue ActiveRecord::RecordInvalid => e
    @channel = e.record
    redirect_to server_path(@server), alert: 'Could not create channel.'
  end

  def update
    Channels::UpdateService.call(channel: @channel, params: channel_params)
    redirect_to server_channel_path(@server, @channel)
  rescue ActiveRecord::RecordInvalid
    redirect_to server_channel_path(@server, @channel), alert: 'Could not update channel.'
  end

  def destroy
    @channel.destroy!
    redirect_to server_path(@server)
  end

  def reorder
    Channels::ReorderService.call(channel: @channel, direction: params[:direction].to_sym)
    redirect_to settings_channels_server_path(@server)
  end

  def archive
    Channels::ArchiveService.call(channel: @channel)
    redirect_to settings_channels_server_path(@server)
  end

  def unarchive
    Channels::UnarchiveService.call(channel: @channel)
    redirect_to settings_channels_server_path(@server)
  end

  def move
    category = @server.all_categories.find(params[:category_id])
    Channels::MoveService.call(channel: @channel, category: category)
    redirect_to settings_channels_server_path(@server)
  end

  private

  def set_server
    @server = Server.find(params[:server_id])
  end

  def set_channel
    @channel = @server.channels.find(params[:id])
  end

  def channel_params
    params.require(:channel).permit(:name, :description, :channel_type, :topic, :is_private)
  end
end
