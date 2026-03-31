require 'test_helper'

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server = servers(:one)
    @channel = channels(:general)
    @message = messages(:one)
    sign_in_as(users(:one))
  end

  test 'create sends a message' do
    assert_difference 'Message.count' do
      post server_channel_messages_path(@server, @channel),
           params: { message: { body: 'Test message' } }
    end
    assert_response :ok
  end

  test 'create with empty body returns unprocessable' do
    assert_no_difference 'Message.count' do
      post server_channel_messages_path(@server, @channel),
           params: { message: { body: '' } }
    end
    assert_response :unprocessable_entity
  end

  test 'create requires membership' do
    sign_in_as(users(:two))
    other_server = servers(:two)
    # user two is not a member of server one's channel
    # but user two IS a member of server one (fixture two_member_of_one)
    # so let's test with a server where they have no membership
    sign_out
    sign_in_as(users(:one))

    # user one is NOT a member of server two
    channel_in_two = Channel.create!(name: 'test', server: other_server, channel_type: :text)
    post server_channel_messages_path(other_server, channel_in_two),
         params: { message: { body: 'Sneaky' } }
    assert_redirected_to servers_path
  end

  test 'edit returns turbo stream for author' do
    get edit_server_channel_message_path(@server, @channel, @message),
        headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    assert_response :ok
  end

  test 'edit forbidden for non-author' do
    sign_out
    sign_in_as(users(:two))
    get edit_server_channel_message_path(@server, @channel, @message),
        headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    assert_response :forbidden
  end

  test 'update edits message body' do
    patch server_channel_message_path(@server, @channel, @message),
          params: { message: { body: 'Updated body' } }
    assert_response :ok
    @message.reload
    assert_equal 'Updated body', @message.body
    assert @message.edited?
  end

  test 'update forbidden for non-author' do
    sign_out
    sign_in_as(users(:two))
    patch server_channel_message_path(@server, @channel, @message),
          params: { message: { body: 'Hacked' } }
    assert_response :forbidden
  end

  test 'destroy soft-deletes message' do
    delete server_channel_message_path(@server, @channel, @message)
    assert_response :ok
    @message.reload
    assert @message.deleted?
  end

  test 'destroy forbidden for non-author' do
    sign_out
    sign_in_as(users(:two))
    delete server_channel_message_path(@server, @channel, @message)
    assert_response :forbidden
  end

  test 'index loads messages' do
    get server_channel_messages_path(@server, @channel, format: :turbo_stream)
    assert_response :ok
  end

  test 'index with before param loads older messages' do
    get server_channel_messages_path(@server, @channel,
                                     before: Time.current.iso8601(6), format: :turbo_stream)
    assert_response :ok
  end
end
