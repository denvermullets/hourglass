require 'test_helper'

module Messages
  class CreateServiceTest < ActiveSupport::TestCase
    test 'creates a message in the channel' do
      channel = channels(:general)
      user = users(:one)

      assert_difference 'Message.count' do
        message = Messages::CreateService.call(
          channel: channel,
          user: user,
          params: { body: 'Hello!' }
        )

        assert message.persisted?
        assert_equal 'Hello!', message.body
        assert_equal user, message.user
        assert_equal channel, message.channel
        assert message.regular?
      end
    end

    test "marks author's membership as read at the new message's timestamp" do
      channel = channels(:general)
      user = users(:one)

      message = Messages::CreateService.call(
        channel: channel,
        user: user,
        params: { body: 'Hello!' }
      )

      membership = ChannelMembership.find_by!(user: user, channel: channel)
      assert_equal message.created_at.to_i, membership.last_read_at.to_i
      assert membership.last_read_at >= channel.reload.last_message_at
    end

    test 'raises on invalid params' do
      channel = channels(:general)
      user = users(:one)

      assert_raises(ActiveRecord::RecordInvalid) do
        Messages::CreateService.call(
          channel: channel,
          user: user,
          params: { body: '' }
        )
      end
    end
  end
end
