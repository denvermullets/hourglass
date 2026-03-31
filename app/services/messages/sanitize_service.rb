class Messages::SanitizeService < Service
  ALLOWED_TAGS = %w[p br strong em s code pre a span ul ol li].freeze
  ALLOWED_ATTRIBUTES = %w[href rel target class data-highlight-language].freeze

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

    # Only allow class attributes with editor- prefix
    sanitized = sanitized.gsub(/class="([^"]*)"/) do
      classes = ::Regexp.last_match(1).split.select { |c| c.start_with?('editor-') }
      classes.any? ? "class=\"#{classes.join(' ')}\"" : ''
    end

    # Strip bare <span> tags with no attributes (Lexical wraps every token in spans)
    sanitized.gsub(%r{<span>([^<]*)</span>}, '\1')
  end
end
