require 'test_helper'

module Messages
  class CreateServiceTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
    include ActiveJob::TestHelper

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

    test "marks author's membership as read at the new message's timestamp" do
      channel = channels(:general)
      user = users(:one)

      message = Messages::CreateService.call(
        channel: channel,
        user: user,
        params: { body: 'Hello!' }
      )

      membership = ChannelMembership.find_by!(user: user, channel: channel)
      assert_equal message.created_at.to_i, membership.last_read_at.to_i
      assert membership.last_read_at >= channel.reload.last_message_at
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

    test 'enqueues outbound emitter when channel is linked to a mtasks project' do
      channel = channels(:general)
      user = users(:one)
      link = MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: server_integrations(:jait_one), channel: channel,
        mtasks_team_id: 21, mtasks_project_id: 7,
        created_by_user: user
      )

      msg = nil
      assert_enqueued_jobs(1, only: MtasksOutboundEmitterJob) do
        msg = Messages::CreateService.call(channel: channel, user: user, params: { body: 'Hi' })
      end

      args = enqueued_jobs.last[:args].first
      assert_equal 'message.created', args['event_type']
      assert_equal msg.id, args['message_id']
      assert_equal link.id, args['link_id']
    end

    test 'does not enqueue when channel is not linked' do
      channel = channels(:general)
      user = users(:one)

      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::CreateService.call(channel: channel, user: user, params: { body: 'Hi' })
      end
    end

    test 'loop guard: does not enqueue when message.data[source] == mtasks' do
      channel = channels(:general)
      user = users(:one)
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: server_integrations(:jait_one), channel: channel,
        mtasks_team_id: 21, mtasks_project_id: 7, created_by_user: user
      )

      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::CreateService.call(
          channel: channel, user: user,
          params: { body: 'echoed back', data: { 'source' => 'mtasks' } }
        )
      end
    end

    test 'system messages do not enqueue outbound emitter' do
      channel = channels(:general)
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: server_integrations(:jait_one), channel: channel,
        mtasks_team_id: 21, mtasks_project_id: 7, created_by_user: users(:one)
      )

      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::CreateSystemService.call(
          channel: channel, body: 'system msg', data: { 'source' => 'mtasks' }
        )
      end
    end

    test 'thread reply with issue_thread link enqueues message.created' do
      channel = channels(:general)
      user = users(:one)
      parent = messages(:one)
      issue_link = MtasksLink.create!(
        link_type: MtasksLink::ISSUE_THREAD,
        server_integration: server_integrations(:jait_one), thread: parent,
        mtasks_team_id: 21, mtasks_issue_id: 91, created_by_user: user
      )

      reply = nil
      assert_enqueued_jobs(1, only: MtasksOutboundEmitterJob) do
        reply = Messages::CreateService.call(
          channel: channel, user: user,
          params: { body: 'reply', parent_message_id: parent.id }
        )
      end

      args = enqueued_jobs.last[:args].first
      assert_equal 'message.created', args['event_type']
      assert_equal reply.id, args['message_id']
      assert_equal issue_link.id, args['link_id']
    end

    test 'stores the raw markdown body and stamps the format flag' do
      channel = channels(:general)
      user = users(:one)
      body = '**bold** and _italic_ with `code`'

      message = Messages::CreateService.call(channel: channel, user: user, params: { body: body })

      assert_equal body, message.body
      assert message.markdown?
      assert_equal 'markdown', message.data['format']
    end

    test 'fans out user.mentioned for a Jait-linked mentioned user on linked channels' do
      channel = channels(:general)
      user = users(:one)
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: server_integrations(:jait_one), channel: channel,
        mtasks_team_id: 21, mtasks_project_id: 7, created_by_user: user
      )

      msg = nil
      assert_enqueued_jobs(2, only: MtasksOutboundEmitterJob) do
        msg = Messages::CreateService.call(channel: channel, user: user, params: { body: 'hey @usertwo' })
      end

      events = enqueued_jobs.map { |j| j[:args].first['event_type'] }
      assert_equal 1, events.count('message.created')
      assert_equal 1, events.count('user.mentioned')

      mention_job = enqueued_jobs.find { |j| j[:args].first['event_type'] == 'user.mentioned' }
      assert_equal 5002, mention_job[:args].first['mtasks_user_id']
      assert_equal msg.id, mention_job[:args].first['message_id']
    end

    test 'does not fan out cross-app mentions when channel is unlinked' do
      channel = channels(:general)
      user = users(:one)

      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::CreateService.call(channel: channel, user: user, params: { body: 'hey @usertwo' })
      end
    end

    test 'thread reply without an issue_thread link does not enqueue' do
      channel = channels(:general)
      user = users(:one)
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: server_integrations(:jait_one), channel: channel,
        mtasks_team_id: 21, mtasks_project_id: 7, created_by_user: user
      )
      parent = messages(:one)

      assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
        Messages::CreateService.call(
          channel: channel, user: user,
          params: { body: 'reply', parent_message_id: parent.id }
        )
      end
    end
  end
end
