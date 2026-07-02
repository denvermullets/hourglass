module MessagesHelper
  GROUP_WINDOW = 60.seconds

  def sanitize_message(message_or_html)
    html, server = extract_html_and_server(message_or_html)
    return '' if html.blank?

    sanitized = Messages::SanitizeService.call(html: html)

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

  # True when the current viewer authored this message/reply. Used to server-render
  # author-only styling (username color, edit/delete visibility) so it survives a morph
  # refresh — replacing the old runtime message_actions_controller.js toggle.
  def message_author?(record)
    Current.user && record.user_id == Current.user.id
  end

  def grouped_with_previous?(message, previous_message)
    return false if previous_message.nil?
    return false if previous_message.deleted?

    previous_message.user_id == message.user_id &&
      (message.created_at - previous_message.created_at) <= GROUP_WINDOW
  end
end
