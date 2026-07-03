require 'test_helper'

module Mentions
  class DetectServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @other = users(:two)
      @channel = channels(:general)
    end

    test 'populates cross_app_mentions for mentioned users linked to Jait' do
      message = @channel.messages.create!(user: @user, body: 'hi @usertwo', message_type: :regular)

      Mentions::DetectService.call(message: message)
      message.reload

      assert_equal(
        [{ 'mtasks_user_id' => 5002, 'email' => 'two@example.com', 'display_name' => 'usertwo' }],
        message.data['cross_app_mentions']
      )
    end

    test 'leaves cross_app_mentions absent when the mentioned user is not linked to Jait' do
      MtasksUserMap.find_by(hourglass_user_id: @other.id).destroy!
      message = @channel.messages.create!(user: @user, body: 'hi @usertwo', message_type: :regular)

      Mentions::DetectService.call(message: message)
      message.reload

      assert_nil message.data['cross_app_mentions']
    end

    test 'still creates local mention notifications alongside cross-app ones' do
      message = @channel.messages.create!(user: @user, body: 'hi @usertwo', message_type: :regular)

      assert_difference -> { @other.notifications.where(notification_type: 'mention').count }, 1 do
        Mentions::DetectService.call(message: message)
      end

      message.reload
      assert_equal 1, message.data['cross_app_mentions'].size
    end

    test 'dedupes repeated mentions of the same user' do
      message = @channel.messages.create!(user: @user, body: '@usertwo @usertwo', message_type: :regular)

      Mentions::DetectService.call(message: message)
      message.reload

      assert_equal 1, message.data['cross_app_mentions'].size
    end
  end
end
