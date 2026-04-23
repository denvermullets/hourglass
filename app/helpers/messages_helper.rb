module MessagesHelper
  GROUP_WINDOW = 60.seconds

  def sanitize_message(message_or_html)
    html, server = extract_html_and_server(message_or_html)
    return '' if html.blank?

    sanitized = sanitize(
      html,
      tags: Messages::SanitizeService::ALLOWED_TAGS,
      attributes: Messages::SanitizeService::ALLOWED_ATTRIBUTES
    )

    highlighted = Messages::HighlightService.call(html: sanitized)
    with_mentions = Mentions::HighlightService.call(html: highlighted, current_user: Current.user)
    with_channels = Channels::HighlightService.call(html: with_mentions)
    Jait::HighlightService.call(html: with_channels, server: server)
  end

  def extract_html_and_server(message_or_html)
    if message_or_html.is_a?(Message)
      [message_or_html.body, message_or_html.channel&.server]
    else
      [message_or_html, nil]
    end
  end

  def grouped_with_previous?(message, previous_message)
    return false if previous_message.nil?
    return false if previous_message.deleted?

    previous_message.user_id == message.user_id &&
      (message.created_at - previous_message.created_at) <= GROUP_WINDOW
  end
end
