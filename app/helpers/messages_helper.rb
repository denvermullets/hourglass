module MessagesHelper
  GROUP_WINDOW = 60.seconds

  def sanitize_message(message_or_html)
    return render_markdown(message_or_html) if message_or_html.is_a?(Message) && message_or_html.markdown?

    html, server = extract_html_and_server(message_or_html)
    return '' if html.blank?

    sanitized = Messages::SanitizeService.call(html: html)

    highlighted = Messages::HighlightService.call(html: sanitized)
    with_mentions = Mentions::HighlightService.call(html: highlighted, current_user: Current.user)
    with_channels = Channels::HighlightService.call(html: with_mentions)
    Jait::HighlightService.call(html: with_channels, server: server)
  end

  # Markdown messages carry raw markdown in body; RenderService turns it into the same
  # final HTML the legacy chain produces (mentions/channels/jait included).
  def render_markdown(message)
    return '' if message.body.blank?

    Messages::RenderService.call(
      markdown: message.body,
      server: message.channel&.server,
      scope: mention_scope(message),
      current_user: Current.user
    )
  end

  # User relation @mentions resolve against: conversation members for DMs, else server members.
  def mention_scope(message)
    message.conversation.present? ? message.conversation.members : message.channel&.server&.users
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
