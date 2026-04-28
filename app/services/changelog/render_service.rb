class Changelog::RenderService < Service
  SHA_MARKER_RE = /\A<!--\s*last-sha:.*?-->\s*\n/m
  TOP_HEADING_RE = /\A#\s+.+?\n/m

  def initialize(text)
    @text = text.to_s
  end

  def call
    body = @text.sub(SHA_MARKER_RE, '').sub(TOP_HEADING_RE, '').strip
    return '' if body.empty?

    Commonmarker.to_html(body)
  end
end
