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
    assert_select 'form#message_form[data-turbo-permanent]'
  end

  test 'page poll-digest matches the /poll endpoint digest for the same context' do
    get server_channel_path(@server, @channel)
    page_digest = css_select('meta[name="poll-digest"]').first['content']

    get poll_path(channel_id: @channel.id)
    assert_equal page_digest, JSON.parse(response.body)['digest']
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
