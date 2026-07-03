class Mentions::HighlightService < Service
  include Html::TextNodeRewriter

  # Not preceded by a word char so emails (e.g. a@usertwo.com) aren't matched.
  MENTION_RE = /(?<!\w)@(\w{3,20})(?!\w)/

  def initialize(html:, current_user: nil, scope: nil, markdown: false)
    @html = html
    @current_user = current_user
    @scope = scope
    @markdown = markdown
  end

  def call
    return @html if @html.blank?

    @markdown ? highlight_text : highlight_spans
  end

  private

  # Markdown messages carry plain @username text. Resolve each against the given user
  # scope (server members or conversation members); unresolved tokens stay plain text.
  def highlight_text
    return @html if @scope.nil?

    tokens = tokens_in(@html, MENTION_RE)
    return @html if tokens.empty?

    users = @scope.where('LOWER(username) IN (?)', tokens).index_by { |user| user.username.downcase }

    rewrite_text_nodes(@html, MENTION_RE) do |match|
      user = users[match[1].downcase]
      next nil unless user

      css = @current_user&.id == user.id ? 'mention mention-self' : 'mention'
      %(<span class="#{css}" data-mention-username="#{user.username}">#{escape(match[0])}</span>)
    end
  end

  # Legacy path: HTML messages embed Lexical <span class="editor-mention"> spans.
  def highlight_spans
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
