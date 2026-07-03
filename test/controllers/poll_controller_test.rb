require 'test_helper'

class PollControllerTest < ActionDispatch::IntegrationTest
  setup do
    @channel = channels(:general)
    sign_in_as(users(:one))
  end

  test 'returns a digest as json' do
    get poll_path(channel_id: @channel.id)
    assert_response :ok
    body = JSON.parse(response.body)
    assert body['digest'].present?
  end

  test 'digest is stable across calls when nothing changes' do
    get poll_path(channel_id: @channel.id)
    first = JSON.parse(response.body)['digest']
    get poll_path(channel_id: @channel.id)
    assert_equal first, JSON.parse(response.body)['digest']
  end

  test 'digest moves after a new message' do
    get poll_path(channel_id: @channel.id)
    before = JSON.parse(response.body)['digest']

    @channel.messages.create!(user: users(:one), body: 'hi', message_type: :regular)

    get poll_path(channel_id: @channel.id)
    refute_equal before, JSON.parse(response.body)['digest']
  end

  test 'requires authentication' do
    sign_out
    get poll_path(channel_id: @channel.id)
    assert_response :redirect
  end

  test 'a request marks the current user seen (DB-backed presence)' do
    assert_nil users(:one).last_seen_at
    get poll_path(channel_id: @channel.id)
    assert_not_nil users(:one).reload.last_seen_at
  end
end
