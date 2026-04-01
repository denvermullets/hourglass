class Mentions::HighlightService < Service
  def initialize(html:, current_user: nil)
    @html = html
    @current_user = current_user
  end

  def call
    return @html if @html.blank?
    return @html unless @html.include?('editor-mention')

    @html.gsub(/<span class="editor-mention"([^>]*)>/) do
      attrs = ::Regexp.last_match(1)
      username = attrs[/data-mention-username="([^"]*)"/, 1]
      is_self = @current_user && username&.downcase == @current_user.username.downcase
      css = is_self ? 'mention mention-self' : 'mention'
      %(<span class="#{css}"#{attrs}>)
    end.html_safe
  end
end
