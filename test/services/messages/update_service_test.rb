require 'test_helper'

module Messages
  class UpdateServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @channel = channels(:general)
      @message = messages(:one)
    end

    test 'enqueues message.updated when message has stored mtasks_comment_id' do
      @message.update!(data: { 'mtasks_comment_id' => 555, 'mtasks_link_id' => 1 })

      assert_enqueued_jobs(1, only: MtasksOutboundEmitterJob) do
        Messages::UpdateService.call(message: @message, params: { body: 'edited' })
      end

      args = enqueued_jobs.last[:args].first
      assert_equal 'message.updated', args['event_type']
      assert_equal @message.id, args['message_id']
    end

    test 'does not enqueue when message has never been emitted' do
      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::UpdateService.call(message: @message, params: { body: 'edited' })
      end
    end

    test 'loop guard: does not enqueue when source is mtasks' do
      @message.update!(data: { 'source' => 'mtasks', 'mtasks_comment_id' => 555 })

      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::UpdateService.call(message: @message, params: { body: 'edited' })
      end
    end
  end
end
