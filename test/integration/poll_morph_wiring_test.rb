require 'test_helper'

# Verifies the layout-level wiring that makes poll-driven Turbo morph refreshes work:
# the morph strategy metas, the poll-digest baseline, and the body poller context.
class PollMorphWiringTest < ActionDispatch::IntegrationTest
  setup do
    @server = servers(:one)
    @channel = channels(:general)
    sign_in_as(users(:one))
  end

  test 'channel page renders morph strategy, poll digest, and body poller context' do
    get server_channel_path(@server, @channel)
    assert_response :ok

    assert_select 'meta[name="turbo-refresh-method"][content="morph"]'
    assert_select 'meta[name="turbo-refresh-scroll"][content="preserve"]'
    digest = css_select('meta[name="poll-digest"]').first['content']
    assert_match(/\A[a-f0-9]{32}\z/, digest)

    assert_select 'body[data-controller~="poller"]'
    assert_select 'body[data-poller-channel-id-value=?]', @channel.id.to_s
    assert_select 'body[data-poller-url-value="/poll"]'

    assert_select '#messages_scroll_container'
    assert_select "form#message_form_channel_#{@channel.id}[data-turbo-permanent]"
  end

  test 'page poll-digest matches the /poll endpoint digest for the same context' do
    get server_channel_path(@server, @channel)
    page_digest = css_select('meta[name="poll-digest"]').first['content']

    get poll_path(channel_id: @channel.id)
    assert_equal page_digest, JSON.parse(response.body)['digest']
  end

  # Settings screens keep state in the DOM (open <select>, half-typed field, active
  # turbo-frame tab) that a morph would reset, and hold nothing the poll keeps fresh.
  test 'settings pages opt out of the poller' do
    %w[server_settings channel_settings user_settings].each do |page|
      case page
      when 'server_settings' then get settings_server_path(@server)
      when 'channel_settings' then get server_channel_settings_path(@server, @channel)
      when 'user_settings' then get profile_settings_path
      end
      assert_response :ok, page

      assert_select 'body[data-controller~="poller"]', false, "#{page} should not attach the poller"
      assert_select 'meta[name="poll-digest"]', false, "#{page} should not render a poll digest"
    end
  end

  # Phase 4: presence is DB-derived; the cable presence/monitor markup is gone.
  test 'presence pill renders from Server#online_count; no cable presence/monitor markup' do
    get server_channel_path(@server, @channel)
    assert_response :ok

    pill = css_select("#server_#{@server.id}_presence").first
    assert pill, 'expected presence indicator'
    assert_match(/online/, pill.text)

    assert_no_match(/data-presence-server-id-value/, response.body)
    assert_no_match(/connection-monitor/, response.body)
  end

  # Author styling is now server-rendered (survives morph) instead of toggled by JS.
  test 'author messages render green username + visible actions; others blue' do
    get server_channel_path(@server, @channel)
    assert_response :ok

    # messages(:one) authored by users(:one) — the signed-in user.
    own = css_select("#message_#{messages(:one).id}").first
    assert_includes own.to_html, 'text-granny-smith-apple-300'
    assert_select "#message_#{messages(:one).id} [data-author-only].flex"

    # messages(:two) authored by users(:two).
    other = css_select("#message_#{messages(:two).id}").first
    assert_includes other.to_html, 'text-jordy-blue-400'
    assert_select "#message_#{messages(:two).id} [data-author-only].hidden"
  end
end
