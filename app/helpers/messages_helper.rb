module MessagesHelper
  def sanitize_message(html)
    return '' if html.blank?

    sanitized = sanitize(
      html,
      tags: Messages::SanitizeService::ALLOWED_TAGS,
      attributes: Messages::SanitizeService::ALLOWED_ATTRIBUTES
    )

    Messages::HighlightService.call(html: sanitized)
  end
end
