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
        channel: @channel, user: @user, args: cmd[:args],
        raw_body: @params[:body], parent_message_id: @params[:parent_message_id]
      )
      return result.message
    end

    attrs = @params.merge(
      body: @params[:body].to_s.strip,
      data: (@params[:data] || {}).merge('format' => 'markdown')
    )

    message = @channel.messages.create!(
      attrs.merge(user: @user, message_type: :regular)
    )

    Messages::PostCreateBroadcaster.call(channel: @channel, user: @user, message: message)
    emit_outbound(message)
    emit_cross_app_mentions(message)

    message
  end

  private

  def emit_outbound(message)
    return unless emittable?(message)

    link = outbound_link_for(message)
    return unless link

    enqueue_create(message, link)
  end

  def emit_cross_app_mentions(message)
    return unless emittable?(message)
    return unless @channel.mtasks_project_link.present?

    mentions = Array(message.data['cross_app_mentions'])
    return if mentions.empty?

    integration = @channel.server.jait_integration
    return unless integration

    mentions.each do |mention|
      mtasks_user_id = mention['mtasks_user_id']
      next if mtasks_user_id.blank?

      enqueue_user_mentioned(
        message: message,
        integration_id: integration.id,
        mtasks_user_id: mtasks_user_id
      )
    end
  end

  def outbound_link_for(message)
    if message.parent_message_id.present?
      MtasksLink.issue_threads.find_by(thread_id: message.parent_message_id)
    else
      @channel.mtasks_project_link
    end
  end
end
