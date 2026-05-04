require 'test_helper'

module Mentions
  class DetectServiceTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @other = users(:two)
      @channel = channels(:general)
    end

    test 'populates cross_app_mentions from external mention spans' do
      body = <<~HTML.squish
        <p>hi <span class="editor-mention" data-mention-username="ext@example.com"
        data-external="true" data-mtasks-user-id="42">@ext@example.com</span></p>
      HTML
      message = @channel.messages.create!(user: @user, body: body, message_type: :regular)

      Mentions::DetectService.call(message: message)
      message.reload

      assert_equal(
        [{ 'mtasks_user_id' => 42, 'email' => 'ext@example.com', 'display_name' => 'ext@example.com' }],
        message.data['cross_app_mentions']
      )
    end

    test 'leaves cross_app_mentions absent when no external spans are present' do
      body = '<p>hi <span class="editor-mention" data-mention-username="usertwo">@usertwo</span></p>'
      message = @channel.messages.create!(user: @user, body: body, message_type: :regular)

      Mentions::DetectService.call(message: message)
      message.reload

      assert_nil message.data['cross_app_mentions']
    end

    test 'still creates local mention notifications alongside external ones' do
      body = <<~HTML.squish
        <p><span class="editor-mention" data-mention-username="usertwo">@usertwo</span>
        <span class="editor-mention" data-mention-username="ext@example.com"
        data-external="true" data-mtasks-user-id="42">@ext@example.com</span></p>
      HTML
      message = @channel.messages.create!(user: @user, body: body, message_type: :regular)

      assert_difference -> { @other.notifications.where(notification_type: 'mention').count }, 1 do
        Mentions::DetectService.call(message: message)
      end

      message.reload
      assert_equal 1, message.data['cross_app_mentions'].size
    end

    test 'dedupes external mentions on the same mtasks_user_id' do
      body = <<~HTML.squish
        <p><span class="editor-mention" data-mention-username="ext@example.com"
        data-external="true" data-mtasks-user-id="42">@ext</span>
        <span class="editor-mention" data-mention-username="ext@example.com"
        data-external="true" data-mtasks-user-id="42">@ext</span></p>
      HTML
      message = @channel.messages.create!(user: @user, body: body, message_type: :regular)

      Mentions::DetectService.call(message: message)
      message.reload

      assert_equal 1, message.data['cross_app_mentions'].size
    end
  end
end
