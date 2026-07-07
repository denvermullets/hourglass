require 'test_helper'

class ChannelTest < ActiveSupport::TestCase
  test 'visible_to includes public channels for everyone' do
    assert_includes Channel.visible_to(users(:two)), channels(:general)
  end

  test 'visible_to excludes private channels the user is not a member of' do
    private_channel = channels(:general)
    private_channel.update!(is_private: true)

    assert_not_includes Channel.visible_to(users(:two)), private_channel
  end

  test 'visible_to includes private channels the user is a member of' do
    private_channel = channels(:general)
    private_channel.update!(is_private: true)
    ChannelMembership.create!(channel: private_channel, user: users(:two))

    assert_includes Channel.visible_to(users(:two)), private_channel
  end
end
