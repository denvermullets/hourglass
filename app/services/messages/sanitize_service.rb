class Messages::SanitizeService < Service
  ALLOWED_TAGS = %w[p br strong em s code pre a span ul ol li blockquote h1 h2 h3 table thead tbody tr th td hr].freeze
  ALLOWED_ATTRIBUTES = %w[href rel target class data-language data-highlight-language data-mention-username
                          data-channel-id data-channel-name data-server-id].freeze

  def initialize(html:)
    @html = html
  end

  def call
    return '' if @html.blank?

    sanitizer = Rails::HTML5::SafeListSanitizer.new
    sanitized = sanitizer.sanitize(
      @html,
      tags: ALLOWED_TAGS,
      attributes: ALLOWED_ATTRIBUTES
    )

    # Only allow class attributes with editor- prefix or text alignment classes
    sanitized = sanitized.gsub(/class="([^"]*)"/) do
      classes = ::Regexp.last_match(1).split.select do |c|
        c.start_with?('editor-') || %w[text-center text-right].include?(c)
      end
      classes.any? ? "class=\"#{classes.join(' ')}\"" : ''
    end

    # Strip bare <span> tags with no attributes (Lexical wraps every token in spans)
    sanitized.gsub(%r{<span>([^<]*)</span>}, '\1')
  end
end
