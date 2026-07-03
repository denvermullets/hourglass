require 'test_helper'

module Channels
  class HighlightServiceTest < ActiveSupport::TestCase
    setup do
      @server = servers(:one)
      @general = channels(:general) # name: general, on server one
    end

    # --- markdown mode ---

    test 'resolves a #channel into an anchor to the channel' do
      html = Channels::HighlightService.call(html: 'see #general', server: @server, markdown: true)

      href = "/servers/#{@server.id}/channels/#{@general.id}"
      assert_includes html, %(<a href="#{href}" class="channel-mention" data-turbo-frame="_top">#general</a>)
    end

    test 'leaves an unknown #channel as plain text' do
      html = Channels::HighlightService.call(html: 'see #random', server: @server, markdown: true)

      assert_includes html, '#random'
      refute_includes html, 'channel-mention'
    end

    test 'leaves #channel as plain text when there is no server (DM)' do
      html = Channels::HighlightService.call(html: 'see #general', server: nil, markdown: true)

      assert_includes html, '#general'
      refute_includes html, 'channel-mention'
    end

    test 'does not match inside code or anchor elements' do
      html = Channels::HighlightService.call(
        html: '<code>#general</code> <a href="/x">#general</a>', server: @server, markdown: true
      )

      refute_includes html, 'class="channel-mention"'
      assert_includes html, '<code>#general</code>'
    end

    # --- legacy span mode ---

    test 'still rewrites editor-channel spans in legacy mode' do
      html = Channels::HighlightService.call(
        html: '<span class="editor-channel" data-channel-id="5" data-server-id="9">#general</span>'
      )

      expected = '<a href="/servers/9/channels/5" class="channel-mention" data-turbo-frame="_top">#general</a>'
      assert_includes html, expected
    end
  end
end
