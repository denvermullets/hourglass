module MessagesHelper
  GROUP_WINDOW = 60.seconds

  def sanitize_message(html)
    return '' if html.blank?

    sanitized = sanitize(
      html,
      tags: Messages::SanitizeService::ALLOWED_TAGS,
      attributes: Messages::SanitizeService::ALLOWED_ATTRIBUTES
    )

    highlighted = Messages::HighlightService.call(html: sanitized)
    Mentions::HighlightService.call(html: highlighted, current_user: Current.user)
  end

  def grouped_with_previous?(message, previous_message)
    return false if previous_message.nil?
    return false if previous_message.deleted?

    previous_message.user_id == message.user_id &&
      (message.created_at - previous_message.created_at) <= GROUP_WINDOW
  end
end
