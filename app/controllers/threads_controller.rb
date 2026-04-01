class ThreadsController < ApplicationController
  include Authorization

  layout 'app'

  before_action :set_server
  before_action :set_channel
  before_action :require_membership!
  before_action :set_parent_message

  def show
    @categories = @server.categories.ordered.includes(:channels)
    @replies = @parent_message.replies.not_deleted.includes(:user).ordered
    @participant_count = @parent_message.thread_participant_count
  end

  private

  def set_server
    @server = Server.find(params[:server_id])
  end

  def set_channel
    @channel = @server.channels.find(params[:channel_id])
  end

  def set_parent_message
    @parent_message = @channel.messages.find(params[:message_id])
  end
end
