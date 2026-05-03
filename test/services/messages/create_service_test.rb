require 'test_helper'

module Messages
  class CreateServiceTest < ActiveSupport::TestCase
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

    test 'thread reply in linked channel does not enqueue (waits for pin)' do
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
