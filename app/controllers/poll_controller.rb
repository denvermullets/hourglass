# Change-check endpoint for the polling-based refresh (Phase 2). Returns a content digest
# for the caller's current context; the poller morphs the page only when it changes.
class PollController < ApplicationController
  def show
    channel = accessible_channel
    conversation = accessible_conversation
    thread = accessible_thread(channel, conversation)

    render json: {
      digest: Polling::DigestService.call(
        user: Current.user, channel:, conversation:, thread:
      )
    }
  end

  private

  def accessible_channel
    return if params[:channel_id].blank?

    Channel.visible_to(Current.user).find_by(id: params[:channel_id])
  end

  def accessible_conversation
    return if params[:conversation_id].blank?

    Conversation.for_user(Current.user).find_by(id: params[:conversation_id])
  end

  # Only honor the thread if it belongs to a container the caller can already see.
  def accessible_thread(channel, conversation)
    return if params[:thread_id].blank?

    thread = Message.find_by(id: params[:thread_id])
    return unless thread
    return unless thread.channel_id == channel&.id || thread.conversation_id == conversation&.id

    thread
  end
end
