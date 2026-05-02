require 'test_helper'

module Messages
  class CreateSystemServiceTest < ActiveSupport::TestCase
    setup do
      @channel = channels(:general)
      @server = @channel.server
    end

    test 'creates a system message with the right attributes' do
      data = { 'source' => 'mtasks', 'event_type' => 'issue.created' }

      assert_difference 'Message.count', 1 do
        message = CreateSystemService.call(channel: @channel, body: '// hello', data: data)

        assert message.system?
        assert_equal '// hello', message.body
        assert_equal data, message.data
        assert_equal @server.owner, message.user # fallback FK
        assert_nil message.parent_message_id
      end
    end

    test 'attributed_user takes precedence over fallback' do
      message = CreateSystemService.call(
        channel: @channel, body: '// hello',
        attributed_user: users(:two)
      )
      assert_equal users(:two), message.user
    end

    test 'thread variant sets parent_message_id and broadcasts to thread stream' do
      parent = messages(:one)
      message = CreateSystemService.call(channel: @channel, body: '// hi thread', parent_message: parent)
      assert_equal parent.id, message.parent_message_id
    end

    test 'does NOT create Notifications even when body looks like a mention' do
      assert_no_difference 'Notification.count' do
        CreateSystemService.call(channel: @channel, body: '// hey @userone status changed')
      end
    end

    test 'does NOT update any ChannelMembership last_read_at' do
      ChannelMembership.create!(user: users(:one), channel: @channel, last_read_at: 1.hour.ago)
      original = users(:one).channel_memberships.find_by(channel: @channel).last_read_at

      CreateSystemService.call(channel: @channel, body: '// hi')

      assert_equal original.to_i, users(:one).channel_memberships.find_by(channel: @channel).reload.last_read_at.to_i
    end

    test 'updates channel.last_message_at to the new message timestamp' do
      message = CreateSystemService.call(channel: @channel, body: '// hi')
      assert_equal message.created_at.to_i, @channel.reload.last_message_at.to_i
    end
  end
end
