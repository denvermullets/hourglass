require 'test_helper'

module Messages
  class UnpinServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @channel = channels(:general)
      @user = users(:one)
      @parent = messages(:one)
      @reply = @channel.messages.create!(
        user: @user, body: 'thread reply', message_type: :regular,
        parent_message: @parent, pinned_at: Time.current, pinned_by: @user
      )
    end

    test 'unpinning a previously emitted thread reply enqueues message.deleted' do
      @reply.update!(data: { 'mtasks_comment_id' => 555, 'mtasks_link_id' => 1 })

      assert_enqueued_jobs(1, only: MtasksOutboundEmitterJob) do
        Messages::UnpinService.call(message: @reply)
      end

      args = enqueued_jobs.last[:args].first
      assert_equal 'message.deleted', args['event_type']
      assert_equal @reply.id, args['message_id']
    end

    test 'unpinning a never-emitted reply does not enqueue' do
      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::UnpinService.call(message: @reply)
      end
    end

    test 'unpinning a root message does not enqueue' do
      root = messages(:two)
      root.update!(pinned_at: Time.current, pinned_by: @user,
                   data: { 'mtasks_comment_id' => 555, 'mtasks_link_id' => 1 })

      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::UnpinService.call(message: root)
      end
    end
  end
end
