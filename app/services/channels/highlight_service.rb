class Channels::HighlightService < Service
  def initialize(html:)
    @html = html
  end

  def call
    return @html if @html.blank?
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
