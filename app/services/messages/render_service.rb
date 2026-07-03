module Messages
  class RenderService < Service
    # Disable Commonmarker's built-in syntax highlighter (it emits inline-styled
    # spans that SanitizeService strips) so our Rouge-based HighlightService does the
    # highlighting instead — consistent with the rest of the message pipeline.
    COMMONMARKER_PLUGINS = { syntax_highlighter: nil }.freeze

    # With the highlighter off, Commonmarker emits fenced code as
    # <pre lang="ruby"><code>. HighlightService reads the language from
    # data-highlight-language on the <pre> (already whitelisted by SanitizeService),
    # so hoist the fence language there before sanitizing. Highlighting runs LAST so
    # Rouge's token classes survive the sanitizer.
    FENCE_LANG_RE = /<pre lang="([^"]+)">/

    def initialize(markdown:)
      @markdown = markdown.to_s
    end

    def call
      return '' if @markdown.blank?

      html = Commonmarker.to_html(@markdown, plugins: COMMONMARKER_PLUGINS)
      html = html.gsub(FENCE_LANG_RE) { %(<pre data-highlight-language="#{Regexp.last_match(1)}">) }
      sanitized = Messages::SanitizeService.call(html: html)
      Messages::HighlightService.call(html: sanitized)
    end
  end
end
