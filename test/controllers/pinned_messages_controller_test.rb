require 'test_helper'

class PinnedMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server = servers(:one)
    @channel = channels(:general)
    sign_in_as(users(:one))
  end

  test 'show lists pinned messages in ascending creation order' do
    older = messages(:one)
    newer = messages(:two)
    older.pin!(users(:one))
    newer.pin!(users(:one))

    get server_channel_pinned_messages_path(@server, @channel)
    assert_response :success

    older_pos = response.body.index("message_#{older.id}")
    newer_pos = response.body.index("message_#{newer.id}")
    assert older_pos, 'expected older message in body'
    assert newer_pos, 'expected newer message in body'
    assert older_pos < newer_pos, 'expected ascending order by created_at'
  end

  test 'show excludes unpinned and deleted messages' do
    pinned = messages(:one)
    pinned.pin!(users(:one))

    get server_channel_pinned_messages_path(@server, @channel)
    assert_response :success

    assert_match(/message_#{pinned.id}/, response.body)
    assert_no_match(/message_#{messages(:two).id}/, response.body)        # not pinned
    assert_no_match(/message_#{messages(:deleted).id}/, response.body)    # deleted
  end

  test 'show empty state when nothing is pinned' do
    get server_channel_pinned_messages_path(@server, @channel)
    assert_response :success
    assert_match(/no pinned messages yet/i, response.body)
  end

  test 'show requires server membership' do
    sign_out
    other_server = servers(:two)
    other_channel = other_server.channels.create!(name: 'general', channel_type: :text, position: 0)
    sign_in_as(users(:one)) # users(:one) is NOT a member of servers(:two)

    get server_channel_pinned_messages_path(other_server, other_channel)
    assert_redirected_to servers_path
  end
end
