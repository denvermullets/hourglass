class Messages::HighlightService < Service
  def initialize(html:)
    @html = html
  end

  def call
    @html.gsub(%r{<pre([^>]*)>(.*?)</pre>}m) do |_match|
      attrs = ::Regexp.last_match(1)
      code_html = ::Regexp.last_match(2)
      language = attrs[/data-highlight-language="([^"]*)"/, 1] ||
                 attrs[/data-language="([^"]*)"/, 1]
      plain_text = extract_plain_text(code_html)

      next empty_code_block if plain_text.blank?

      highlight(plain_text, language)
    end.html_safe
  end

  private

  def extract_plain_text(code_html)
    text = code_html
           .gsub('<br>', "\n")
           .gsub(%r{</?span[^>]*>}, '')
           .gsub(%r{</?code[^>]*>}, '')
    CGI.unescapeHTML(text).strip
  end

  def highlight(text, language)
    lexer = find_lexer(text, language)
    formatter = Rouge::Formatters::HTML.new
    highlighted = formatter.format(lexer.lex(text))
    lang_attr = language.present? ? " data-highlight-language=\"#{language}\"" : ''
    "<pre class=\"editor-code-block highlight\"#{lang_attr}>#{highlighted}</pre>"
  rescue StandardError
    empty_code_block(text)
  end

  def find_lexer(text, language)
    return Rouge::Lexer.guess(source: text) if language.blank?

    Rouge::Lexer.find(language) || Rouge::Lexer.guess(source: text)
  end

  def empty_code_block(text = '')
    escaped = ERB::Util.html_escape(text)
    "<pre class=\"editor-code-block\">#{escaped}</pre>"
  end
end
