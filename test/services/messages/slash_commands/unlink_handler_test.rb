require 'test_helper'

module Messages
  module SlashCommands
    class UnlinkHandlerTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        @channel = channels(:general)
        @user = users(:one)
        @integration = server_integrations(:jait_one)
        @parent = @channel.messages.create!(user: @user, message_type: :regular, body: 'thread root')
      end

      def link_thread!(identifier: 'HOUR-9001', issue_id: 9001)
        MtasksLink.create!(
          link_type: MtasksLink::ISSUE_THREAD,
          server_integration: @integration, thread: @parent,
          mtasks_issue_id: issue_id, mtasks_issue_identifier: identifier,
          mtasks_team_id: 21,
          created_by_user: @user
        )
      end

      test 'happy path destroys the link and enqueues link.removed' do
        link_thread!

        assert_enqueued_jobs 1, only: MtasksOutboundEmitterJob do
          assert_difference 'MtasksLink.issue_threads.count', -1 do
            result = UnlinkHandler.call(
              channel: @channel, user: @user, args: '',
              parent_message_id: @parent.id
            )
            assert result.ok
            msg = result.message
            assert msg.system?
            assert_equal @parent.id, msg.parent_message_id
            assert_match(/Unlinked from HOUR-9001/, msg.body)
          end
        end

        args = enqueued_jobs.last[:args].first
        assert_equal 'link.removed', args['event_type']
        assert_equal 'issue_thread', args['data']['link_type']
        assert_equal 9001, args['data']['mtasks_issue_id']
        assert_equal @parent.id, args['data']['hourglass_thread_id']
      end

      test 'not in a thread posts a system message and enqueues no job' do
        assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
          result = UnlinkHandler.call(channel: @channel, user: @user, args: '')
          assert_not result.ok
          assert_match(/inside a thread/, result.message.body)
        end
      end

      test 'thread not linked posts a system message and enqueues no job' do
        assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
          assert_no_difference 'MtasksLink.issue_threads.count' do
            result = UnlinkHandler.call(
              channel: @channel, user: @user, args: '',
              parent_message_id: @parent.id
            )
            assert_not result.ok
            assert_match(/isn't linked/, result.message.body)
          end
        end
      end
    end
  end
end
