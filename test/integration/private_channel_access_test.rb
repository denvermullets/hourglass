require 'test_helper'

class PrivateChannelAccessTest < ActionDispatch::IntegrationTest
  test 'member without access is redirected from a private channel' do
    channel = channels(:general)
    channel.update!(is_private: true)
    sign_in_as(users(:two)) # plain member of server one, no channel_membership

    get server_channel_path(servers(:one), channel)

    assert_redirected_to server_path(servers(:one))
  end

  test 'member with a channel membership can view a private channel' do
    channel = channels(:general)
    channel.update!(is_private: true)
    ChannelMembership.create!(channel: channel, user: users(:two))
    sign_in_as(users(:two))

    get server_channel_path(servers(:one), channel)

    assert_response :success
  end

  test 'admin bypasses private-channel restrictions without a membership' do
    channel = channels(:general)
    channel.update!(is_private: true)
    sign_in_as(users(:three)) # admin of server one, no channel_membership

    get server_channel_path(servers(:one), channel)

    assert_response :success
  end
end
