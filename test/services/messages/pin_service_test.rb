require 'test_helper'

module Messages
  class PinServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @channel = channels(:general)
      @user = users(:one)
      @integration = server_integrations(:jait_one)
      @parent = messages(:one)
      @reply = @channel.messages.create!(
        user: @user, body: 'thread reply', message_type: :regular,
        parent_message: @parent
      )
    end

    test 'pinning a thread reply with an issue_thread link enqueues message.pinned' do
      issue_link = MtasksLink.create!(
        link_type: MtasksLink::ISSUE_THREAD,
        server_integration: @integration, thread: @parent,
        mtasks_team_id: 21, mtasks_issue_id: 91,
        created_by_user: @user
      )

      assert_enqueued_jobs(1, only: MtasksOutboundEmitterJob) do
        Messages::PinService.call(message: @reply, user: @user)
      end

      args = enqueued_jobs.last[:args].first
      assert_equal 'message.pinned', args['event_type']
      assert_equal @reply.id, args['message_id']
      assert_equal issue_link.id, args['link_id']
    end

    test 'pinning a thread reply without an issue link does not enqueue' do
      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::PinService.call(message: @reply, user: @user)
      end
    end

    test 'pinning a root message in a project-linked channel enqueues message.pinned' do
      project_link = MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: @integration, channel: @channel,
        mtasks_team_id: 21, mtasks_project_id: 7, created_by_user: @user
      )

      assert_enqueued_jobs(1, only: MtasksOutboundEmitterJob) do
        Messages::PinService.call(message: messages(:two), user: @user)
      end

      args = enqueued_jobs.last[:args].first
      assert_equal 'message.pinned', args['event_type']
      assert_equal project_link.id, args['link_id']
    end

    test 'pinning a root message in an unlinked channel does not enqueue' do
      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::PinService.call(message: messages(:two), user: @user)
      end
    end

    test 'loop guard: does not enqueue when source is mtasks' do
      @reply.update!(data: { 'source' => 'mtasks' })
      MtasksLink.create!(
        link_type: MtasksLink::ISSUE_THREAD,
        server_integration: @integration, thread: @parent,
        mtasks_team_id: 21, mtasks_issue_id: 91, created_by_user: @user
      )

      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::PinService.call(message: @reply, user: @user)
      end
    end
  end
end
