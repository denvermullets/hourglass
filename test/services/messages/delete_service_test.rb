require 'test_helper'

module Messages
  class DeleteServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @channel = channels(:general)
      @message = messages(:one)
    end

    test 'soft-deletes the message' do
      Messages::DeleteService.call(message: @message)
      assert @message.reload.deleted?
    end

    test 'enqueues message.deleted when message has stored mtasks_comment_id' do
      @message.update!(data: { 'mtasks_comment_id' => 555, 'mtasks_link_id' => 1 })

      assert_enqueued_jobs(1, only: MtasksOutboundEmitterJob) do
        Messages::DeleteService.call(message: @message)
      end

      args = enqueued_jobs.last[:args].first
      assert_equal 'message.deleted', args['event_type']
      assert_equal @message.id, args['message_id']
    end

    test 'does not enqueue when message has never been emitted' do
      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::DeleteService.call(message: @message)
      end
    end

    test 'loop guard: does not enqueue when source is mtasks' do
      @message.update!(data: { 'source' => 'mtasks', 'mtasks_comment_id' => 555 })

      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::DeleteService.call(message: @message)
      end
    end
  end
end
