class PinnedMessagesController < ApplicationController
  include Authorization

  layout 'app'

  before_action :set_server
  before_action :set_channel
  before_action :require_membership!

  def show
    @pinned_messages = @channel.messages
                               .not_deleted
                               .pinned
                               .includes(:user, :pinned_by, files_attachments: :blob)
    @categories = @server.categories.includes(:channels)
  end

  private

  def set_server
    @server = Server.find(params[:server_id])
  end

  def set_channel
    @channel = @server.channels.find(params[:channel_id])
  end
end
