class ChannelsController < ApplicationController
  include Authorization

  layout 'app'

  before_action :set_server
  before_action :set_channel, only: %i[show update destroy]
  before_action :require_membership!
  before_action :require_moderator!, only: %i[create update destroy]

  def show
    @categories = @server.categories.ordered.includes(:channels)
    messages = @channel.messages.not_deleted.includes(:user).order(created_at: :desc).limit(51)
    @has_older = messages.size > 50
    @messages = messages.first(50).reverse
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
