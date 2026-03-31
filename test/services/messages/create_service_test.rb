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
