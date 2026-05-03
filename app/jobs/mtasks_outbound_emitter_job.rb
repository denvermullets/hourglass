class MtasksOutboundEmitterJob < ApplicationJob
  queue_as :default

  LINK_EVENTS = %w[link.created link.removed].freeze
  MESSAGE_EVENTS = %w[message.created message.updated message.deleted].freeze
  SUPPORTED_EVENTS = (LINK_EVENTS + MESSAGE_EVENTS).freeze

  discard_on ActiveJob::DeserializationError
  discard_on Jait::ApiClient::NotFound
  discard_on Jait::ApiClient::Unauthorized
  retry_on Jait::ApiClient::Error, wait: :polynomially_longer, attempts: 5

  def perform(event_type:, **payload)
    unless SUPPORTED_EVENTS.include?(event_type)
      Rails.logger.warn("[mtasks-outbound] unsupported event #{event_type}")
      return
    end

    if LINK_EVENTS.include?(event_type)
      handle_link_event(event_type, payload)
    else
      handle_message_event(event_type, payload)
    end
  end

  private

  def handle_link_event(event_type, payload)
    Rails.logger.info(
      "[mtasks-outbound] TODO emit #{event_type} for integration=#{payload[:integration_id]}: #{payload[:data].inspect}"
    )
  end

  def handle_message_event(event_type, payload)
    message = Message.find_by(id: payload[:message_id])
    return Rails.logger.warn("[mtasks-outbound] #{event_type} missing message #{payload[:message_id]}") unless message

    case event_type
    when 'message.created' then emit_create(message, payload[:link_id])
    when 'message.updated' then emit_update(message)
    when 'message.deleted' then emit_delete(message)
    end
  end

  def emit_create(message, link_id)
    link = MtasksLink.find_by(id: link_id)
    return Rails.logger.warn("[mtasks-outbound] message.created missing link #{link_id}") unless link

    client = Jait::ApiClient.new(link.server_integration)
    resp = post_comment(client, link, message)
    return unless resp.is_a?(Hash)

    comment_id = resp['id'] || resp.dig('comment', 'id')
    return unless comment_id

    message.update_columns(
      data: message.data.merge('mtasks_comment_id' => comment_id, 'mtasks_link_id' => link.id)
    )
  end

  def emit_update(message)
    link, comment_id = lookup_link_and_comment(message, 'message.updated')
    return unless link && comment_id

    Jait::ApiClient.new(link.server_integration).update_comment(
      team_id: link.mtasks_team_id, comment_id: comment_id, body: message.body
    )
  end

  def emit_delete(message)
    link, comment_id = lookup_link_and_comment(message, 'message.deleted')
    return unless link && comment_id

    Jait::ApiClient.new(link.server_integration).delete_comment(
      team_id: link.mtasks_team_id, comment_id: comment_id
    )
    message.update_columns(data: message.data.except('mtasks_comment_id', 'mtasks_link_id'))
  end

  def post_comment(client, link, message)
    if link.issue_thread?
      client.post_issue_comment(
        team_id: link.mtasks_team_id, issue_id: link.mtasks_issue_id,
        body: message.body, idempotency_key: message.id
      )
    else
      client.post_project_comment(
        team_id: link.mtasks_team_id, project_id: link.mtasks_project_id,
        body: message.body, idempotency_key: message.id
      )
    end
  end

  def lookup_link_and_comment(message, event_type)
    comment_id = message.data['mtasks_comment_id']
    link_id = message.data['mtasks_link_id']
    unless comment_id && link_id
      Rails.logger.warn("[mtasks-outbound] #{event_type} missing comment/link metadata on message #{message.id}")
      return [nil, nil]
    end

    link = MtasksLink.find_by(id: link_id)
    Rails.logger.warn("[mtasks-outbound] #{event_type} missing link #{link_id}") unless link
    [link, comment_id]
  end
end
