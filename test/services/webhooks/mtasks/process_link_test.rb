require 'test_helper'

module Webhooks
  module Mtasks
    class ProcessLinkTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
      include ActiveJob::TestHelper

      setup do
        @server = servers(:one)
        @channel = channels(:general)
        @integration = server_integrations(:jait_one)
        @integration.update!(discovered_teams: [{ 'id' => 21, 'identifier' => 'HOUR', 'name' => 'Hourglass' }])
      end

      def build_delivery(event:, data:)
        WebhookDelivery.create!(
          source: WebhookDelivery::SOURCE_MTASKS,
          delivery_id: SecureRandom.uuid,
          event_type: event,
          received_at: Time.current,
          payload: { 'event' => event, 'data' => data }
        )
      end

      # ---- project_channel happy path ----

      test 'project_channel link.created creates the link with resolved team' do
        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 7,
                                    'hourglass_channel_id' => @channel.id,
                                    'created_by_user_id' => 5001
                                  })

        assert_difference 'MtasksLink.count', 1 do
          result = ProcessLink.call(delivery: delivery)
          assert result.ok, result.error
        end

        link = MtasksLink.last
        assert_equal MtasksLink::PROJECT_CHANNEL, link.link_type
        assert_equal @channel.id, link.channel_id
        assert_equal 7, link.mtasks_project_id
        assert_equal 21, link.mtasks_team_id
        assert_equal users(:one), link.created_by_user # mapped via mtasks_user_maps fixture
        assert_equal @integration, link.server_integration
      end

      test 'project_channel link.created is idempotent' do
        data = {
          'link_type' => 'project_channel',
          'mtasks_project_id' => 7,
          'hourglass_channel_id' => @channel.id,
          'created_by_user_id' => 5001
        }

        ProcessLink.call(delivery: build_delivery(event: 'link.created', data: data))
        assert_no_difference 'MtasksLink.count' do
          result = ProcessLink.call(delivery: build_delivery(event: 'link.created', data: data))
          assert result.ok
        end
      end

      test 'project_channel link.removed destroys the link' do
        link = MtasksLink.create!(
          link_type: MtasksLink::PROJECT_CHANNEL,
          server_integration: @integration, channel: @channel,
          mtasks_team_id: 21, mtasks_project_id: 7,
          created_by_user: users(:one)
        )

        delivery = build_delivery(event: 'link.removed', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 7,
                                    'hourglass_channel_id' => @channel.id
                                  })

        assert_difference 'MtasksLink.count', -1 do
          result = ProcessLink.call(delivery: delivery)
          assert result.ok
        end
        assert_raises(ActiveRecord::RecordNotFound) { link.reload }
      end

      test 'project_channel link.removed when no link exists is a no-op' do
        delivery = build_delivery(event: 'link.removed', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 999,
                                    'hourglass_channel_id' => @channel.id
                                  })

        assert_no_difference 'MtasksLink.count' do
          result = ProcessLink.call(delivery: delivery)
          assert result.ok
        end
      end

      # ---- project_channel error paths ----

      test 'rejects when channel not found' do
        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 7,
                                    'hourglass_channel_id' => 999_999
                                  })

        assert_no_difference 'MtasksLink.count' do
          result = ProcessLink.call(delivery: delivery)
          assert_not result.ok
          assert_match(/channel not found/, result.error)
        end
      end

      test 'rejects when no enabled integration' do
        @integration.update!(enabled: false)

        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 7,
                                    'hourglass_channel_id' => @channel.id
                                  })

        result = ProcessLink.call(delivery: delivery)
        assert_not result.ok
        assert_match(/no enabled integration/, result.error)
      end

      test 'rejects when team_id cannot be resolved' do
        @integration.update!(discovered_teams: [
                               { 'id' => 21, 'identifier' => 'HOUR', 'name' => 'Hourglass' },
                               { 'id' => 22, 'identifier' => 'OTHER', 'name' => 'Other' }
                             ])

        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 7,
                                    'hourglass_channel_id' => @channel.id
                                  })

        with_stubbed_class_method(Jait::Fetcher, :call, nil) do
          result = ProcessLink.call(delivery: delivery)
          assert_not result.ok
          assert_match(/team not resolvable/, result.error)
        end
      end

      # ---- issue_thread ----

      test 'issue_thread happy path creates the link when issue project matches channel' do
        MtasksLink.create!(
          link_type: MtasksLink::PROJECT_CHANNEL,
          server_integration: @integration, channel: @channel,
          mtasks_team_id: 21, mtasks_project_id: 7,
          created_by_user: users(:one)
        )
        parent = messages(:one) # in channels(:general)

        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'issue_thread',
                                    'mtasks_issue_id' => 91,
                                    'mtasks_issue_identifier' => 'HOUR-91',
                                    'hourglass_thread_id' => parent.id,
                                    'created_by_user_id' => 5002
                                  })

        with_stubbed_class_method(Jait::Fetcher, :call, { 'id' => 91, 'project_id' => 7 }) do
          assert_difference 'MtasksLink.count', 1 do
            result = ProcessLink.call(delivery: delivery)
            assert result.ok, result.error
          end
        end

        link = MtasksLink.where(link_type: MtasksLink::ISSUE_THREAD).last
        assert_equal parent.id, link.thread_id
        assert_equal 91, link.mtasks_issue_id
        assert_equal 'HOUR-91', link.mtasks_issue_identifier
        assert_equal users(:two), link.created_by_user
      end

      test 'issue_thread rejects when channel has no project link' do
        parent = messages(:one)
        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'issue_thread',
                                    'mtasks_issue_id' => 91,
                                    'hourglass_thread_id' => parent.id
                                  })

        assert_no_difference 'MtasksLink.count' do
          result = ProcessLink.call(delivery: delivery)
          assert_not result.ok
          assert_match(/thread channel has no project link/, result.error)
        end
      end

      test 'issue_thread rejects when issue project mismatches channel project' do
        MtasksLink.create!(
          link_type: MtasksLink::PROJECT_CHANNEL,
          server_integration: @integration, channel: @channel,
          mtasks_team_id: 21, mtasks_project_id: 7,
          created_by_user: users(:one)
        )
        parent = messages(:one)
        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'issue_thread',
                                    'mtasks_issue_id' => 91,
                                    'hourglass_thread_id' => parent.id
                                  })

        with_stubbed_class_method(Jait::Fetcher, :call, { 'id' => 91, 'project_id' => 999 }) do
          result = ProcessLink.call(delivery: delivery)
          assert_not result.ok
          assert_match(/issue project mismatch/, result.error)
        end
      end

      test 'issue_thread link.removed destroys the link' do
        MtasksLink.create!(
          link_type: MtasksLink::PROJECT_CHANNEL,
          server_integration: @integration, channel: @channel,
          mtasks_team_id: 21, mtasks_project_id: 7,
          created_by_user: users(:one)
        )
        parent = messages(:one)
        link = MtasksLink.create!(
          link_type: MtasksLink::ISSUE_THREAD,
          server_integration: @integration, thread: parent,
          mtasks_team_id: 21, mtasks_issue_id: 91,
          created_by_user: users(:one)
        )

        delivery = build_delivery(event: 'link.removed', data: {
                                    'link_type' => 'issue_thread',
                                    'mtasks_issue_id' => 91,
                                    'hourglass_thread_id' => parent.id
                                  })

        assert_difference 'MtasksLink.count', -1 do
          result = ProcessLink.call(delivery: delivery)
          assert result.ok
        end
        assert_raises(ActiveRecord::RecordNotFound) { link.reload }
      end

      # ---- creator resolution ----

      test 'creator falls back to server.owner when no MtasksUserMap exists' do
        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 7,
                                    'hourglass_channel_id' => @channel.id,
                                    'created_by_user_id' => 9999 # no map for this id
                                  })

        ProcessLink.call(delivery: delivery)
        assert_equal @server.owner, MtasksLink.last.created_by_user
      end

      # ---- no-loop guarantee ----

      test 'inbound processing does not enqueue MtasksOutboundEmitterJob' do
        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 7,
                                    'hourglass_channel_id' => @channel.id
                                  })

        assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
          ProcessLink.call(delivery: delivery)
        end
      end

      # ---- broadcast ----

      def capture_turbo_replace_targets
        captured = []
        Turbo::StreamsChannel.singleton_class.alias_method(:_orig_broadcast_replace_to, :broadcast_replace_to)
        Turbo::StreamsChannel.define_singleton_method(:broadcast_replace_to) { |*_args, **kwargs| captured << kwargs[:target] }
        yield
        captured
      ensure
        Turbo::StreamsChannel.singleton_class.alias_method(:broadcast_replace_to, :_orig_broadcast_replace_to)
        Turbo::StreamsChannel.singleton_class.send(:remove_method, :_orig_broadcast_replace_to)
      end

      test 'project_channel create broadcasts header replace to channel stream' do
        delivery = build_delivery(event: 'link.created', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 7,
                                    'hourglass_channel_id' => @channel.id
                                  })

        targets = capture_turbo_replace_targets { ProcessLink.call(delivery: delivery) }
        assert_includes targets, "channel_#{@channel.id}_jait_linked_badge"
      end

      test 'project_channel remove broadcasts header replace to channel stream' do
        MtasksLink.create!(
          link_type: MtasksLink::PROJECT_CHANNEL,
          server_integration: @integration, channel: @channel,
          mtasks_team_id: 21, mtasks_project_id: 7,
          created_by_user: users(:one)
        )

        delivery = build_delivery(event: 'link.removed', data: {
                                    'link_type' => 'project_channel',
                                    'mtasks_project_id' => 7,
                                    'hourglass_channel_id' => @channel.id
                                  })

        targets = capture_turbo_replace_targets { ProcessLink.call(delivery: delivery) }
        assert_includes targets, "channel_#{@channel.id}_jait_linked_badge"
      end
    end
  end
end
