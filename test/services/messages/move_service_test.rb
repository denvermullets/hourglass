require 'test_helper'

module Messages
  class MoveServiceTest < ActiveSupport::TestCase
    setup do
      @server = servers(:one)
      @source = channels(:general)
      @target = @server.channels.create!(name: 'releases', category: categories(:general), channel_type: :text)
      @user = users(:one)
    end

    test 'moves a root message to the target channel' do
      message = @source.messages.create!(body: 'ship it', user: @user, message_type: :regular)

      Messages::MoveService.call(message: message, target_channel: @target)

      assert_equal @target.id, message.reload.channel_id
    end

    test 'moves threaded replies along with the root' do
      root = @source.messages.create!(body: 'topic', user: @user, message_type: :regular)
      reply_a = @source.messages.create!(body: 'reply a', user: @user, parent_message: root, message_type: :regular)
      reply_b = @source.messages.create!(body: 'reply b', user: @user, parent_message: root, message_type: :regular)

      Messages::MoveService.call(message: root, target_channel: @target)

      assert_equal @target.id, reply_a.reload.channel_id
      assert_equal @target.id, reply_b.reload.channel_id
      assert_equal root.id, reply_a.parent_message_id, 'threading is preserved'
    end

    test 'recomputes last_message_at on both channels' do
      moved = @source.messages.create!(body: 'newest', user: @user, message_type: :regular, created_at: 1.minute.ago)
      @source.update_column(:last_message_at, moved.created_at)
      @target.update_column(:last_message_at, nil)

      Messages::MoveService.call(message: moved, target_channel: @target)

      assert @source.reload.last_message_at < moved.created_at,
             'source drops the moved message and falls back to an older one'
      assert_in_delta moved.created_at.to_f, @target.reload.last_message_at.to_f, 1,
                      'target reflects the moved message timestamp'
    end

    test 'is a no-op when already in the target channel' do
      message = @target.messages.create!(body: 'already here', user: @user, message_type: :regular)

      assert_no_changes -> { message.reload.updated_at } do
        Messages::MoveService.call(message: message, target_channel: @target)
      end
    end

    test 'does not move a reply on its own' do
      root = @source.messages.create!(body: 'topic', user: @user, message_type: :regular)
      reply = @source.messages.create!(body: 'reply', user: @user, parent_message: root, message_type: :regular)

      Messages::MoveService.call(message: reply, target_channel: @target)

      assert_equal @source.id, reply.reload.channel_id
    end
  end
end
