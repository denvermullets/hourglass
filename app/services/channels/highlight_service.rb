class Channels::HighlightService < Service
  include Html::TextNodeRewriter

  CHANNEL_RE = /(?<!\w)#([\w-]+)/

  def initialize(html:, server: nil, markdown: false)
    @html = html
    @server = server
    @markdown = markdown
  end

  def call
    return @html if @html.blank?

    @markdown ? highlight_text : highlight_spans
  end

  private

  # Markdown messages carry plain #channel text. Resolve each name against the server's
  # channels; unresolved tokens (and DMs, where @server is nil) stay plain text.
  def highlight_text
    return @html if @server.nil?

    tokens = tokens_in(@html, CHANNEL_RE)
    return @html if tokens.empty?

    channels = @server.channels.where('LOWER(name) IN (?)', tokens).index_by { |channel| channel.name.downcase }

    rewrite_text_nodes(@html, CHANNEL_RE) do |match|
      channel = channels[match[1].downcase]
      next nil unless channel

      path = "/servers/#{@server.id}/channels/#{channel.id}"
      %(<a href="#{path}" class="channel-mention" data-turbo-frame="_top">#{escape(match[0])}</a>)
    end
  end

  # Legacy path: HTML messages embed Lexical <span class="editor-channel"> spans.
  def highlight_spans
    return @html unless @html.include?('editor-channel')

    @html.gsub(%r{<span class="editor-channel"([^>]*)>(.*?)</span>}) do
      attrs = ::Regexp.last_match(1)
      text = ::Regexp.last_match(2)
      channel_id = attrs[/data-channel-id="([^"]*)"/, 1]
      server_id = attrs[/data-server-id="([^"]*)"/, 1]

      if channel_id && server_id
        path = "/servers/#{server_id}/channels/#{channel_id}"
        %(<a href="#{path}" class="channel-mention" data-turbo-frame="_top">#{text}</a>)
      else
        %(<span class="channel-mention"#{attrs}>#{text}</span>)
      end
    end.html_safe
  end
end
