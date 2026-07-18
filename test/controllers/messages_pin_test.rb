require 'test_helper'

class MessagesPinTest < ActionDispatch::IntegrationTest
  setup do
    @server = servers(:one)
    @channel = channels(:general)
    @message = messages(:one) # authored by users(:one)
    sign_in_as(users(:one))
  end

  test 'pin sets pinned_at and pinned_by' do
    freeze_time do
      post pin_server_channel_message_path(@server, @channel, @message)
      assert_response :ok

      @message.reload
      assert @message.pinned?
      assert_equal Time.current, @message.pinned_at
      assert_equal users(:one).id, @message.pinned_by_id
    end
  end

  test 'a non-author channel member can pin' do
    sign_out
    sign_in_as(users(:two)) # member of server one via fixtures

    post pin_server_channel_message_path(@server, @channel, @message)
    assert_response :ok
    assert @message.reload.pinned?
    assert_equal users(:two).id, @message.pinned_by_id
  end

  test 'pin requires server membership' do
    other_server = servers(:two)
    other_channel = other_server.channels.create!(name: 'general', channel_type: :text, position: 0)
    foreign_message = other_channel.messages.create!(user: users(:two), body: 'hi', message_type: :regular)

    post pin_server_channel_message_path(other_server, other_channel, foreign_message)
    assert_redirected_to servers_path
    assert_not foreign_message.reload.pinned?
  end

  test 'pinning the same message twice is idempotent' do
    @message.pin!(users(:one))
    assert_no_changes -> { @message.reload.pinned_at } do
      post pin_server_channel_message_path(@server, @channel, @message)
      assert_response :ok
    end
  end

  test 'unpin clears pinned columns' do
    @message.pin!(users(:one))
    delete pin_server_channel_message_path(@server, @channel, @message)
    assert_response :ok

    @message.reload
    assert_not @message.pinned?
    assert_nil @message.pinned_by_id
  end

  test 'unpinning an already-unpinned message is a no-op' do
    delete pin_server_channel_message_path(@server, @channel, @message)
    assert_response :ok
    assert_not @message.reload.pinned?
  end

  # The pinned state has to land on the actor's screen immediately rather than waiting
  # for the next poll+morph, so both actions echo turbo_streams like create/update/destroy.
  test 'pin echoes streams for the message and the pinned count' do
    post pin_server_channel_message_path(@server, @channel, @message)

    assert_equal Mime[:turbo_stream], response.media_type
    assert_select 'turbo-stream[action=replace][target=?]', dom_id(@message)
    assert_select 'turbo-stream[action=replace][target=?]', "channel_#{@channel.id}_pinned_count"
  end

  test 'unpin echoes streams for the message and the pinned count' do
    @message.pin!(users(:one))

    delete pin_server_channel_message_path(@server, @channel, @message)

    assert_equal Mime[:turbo_stream], response.media_type
    assert_select 'turbo-stream[action=replace][target=?]', dom_id(@message)
    assert_select 'turbo-stream[action=replace][target=?]', "channel_#{@channel.id}_pinned_count"
  end

  test 'pinned message stream renders the pinned chrome and an unpin link' do
    post pin_server_channel_message_path(@server, @channel, @message)

    assert_select 'turbo-stream[target=?]', dom_id(@message) do
      assert_match(%r{// pinned}, response.body)
      assert_match(/unpin/, response.body)
    end
  end

  test 'pinning a thread reply echoes streams without a pinned count target in the DOM' do
    reply = @channel.messages.create!(user: users(:one), body: 'reply', message_type: :regular,
                                      parent_message: @message)

    post pin_server_channel_message_path(@server, @channel, reply)

    assert_response :ok
    assert_select 'turbo-stream[action=replace][target=?]', dom_id(reply)
    assert reply.reload.pinned?
  end
end
