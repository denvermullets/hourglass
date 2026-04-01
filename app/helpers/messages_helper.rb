module MessagesHelper
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
end
