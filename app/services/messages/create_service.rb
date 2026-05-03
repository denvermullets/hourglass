class Messages::CreateService < Service
  include Messages::MtasksEmittable

  def initialize(channel:, user:, params:)
    @channel = channel
    @user = user
    @params = params
  end

  def call
    if (cmd = Messages::SlashCommandParser.detect(@params[:body]))
      result = cmd[:command].handler.call(
        channel: @channel, user: @user, args: cmd[:args], raw_body: @params[:body]
      )
      return result.message
    end

    sanitized_params = @params.merge(
      body: Messages::SanitizeService.call(html: @params[:body])
    )

    message = @channel.messages.create!(
      sanitized_params.merge(user: @user, message_type: :regular)
    )

    Messages::PostCreateBroadcaster.call(channel: @channel, user: @user, message: message)
    emit_outbound(message)

    message
  end

  private

  def emit_outbound(message)
    return unless emittable?(message)

    link = outbound_link_for(message)
    return unless link

    enqueue_create(message, link)
  end

  def outbound_link_for(message)
    if message.parent_message_id.present?
      MtasksLink.issue_threads.find_by(thread_id: message.parent_message_id)
    else
      @channel.mtasks_project_link
    end
  end
end
