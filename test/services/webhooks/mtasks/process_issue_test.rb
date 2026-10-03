require 'test_helper'

module Webhooks
  module Mtasks
    class ProcessIssueTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
      include ActiveJob::TestHelper

      setup do
        @server = servers(:one)
        @channel = channels(:general)
        @integration = server_integrations(:jait_one)
        @integration.update!(discovered_teams: [{ 'id' => 21, 'identifier' => 'HOUR', 'name' => 'Hourglass' }])
        @link = MtasksLink.create!(
          link_type: MtasksLink::PROJECT_CHANNEL,
          server_integration: @integration, channel: @channel,
          mtasks_team_id: 21, mtasks_project_id: 7,
          created_by_user: users(:one)
        )
      end

      def build_delivery(event:, data:, integration: @integration)
        WebhookDelivery.create!(
          source: WebhookDelivery::SOURCE_MTASKS,
          server_integration: integration,
          delivery_id: SecureRandom.uuid,
          event_type: event,
          received_at: Time.current,
          payload: { 'event' => event, 'data' => data }
        )
      end

      # A second tenant: its own server, JAIT integration, channel and thread
      # root. Deliveries signed by @integration must never touch any of it.
      def build_other_server
        @other_server = servers(:two)
        @other_integration = ServerIntegration.create!(
          server: @other_server, kind: ServerIntegration::KIND_JAIT, enabled: true,
          api_token: 'test-token-2', base_url: 'https://justanotherissuetracker.com',
          discovered_teams: [{ 'id' => 31, 'identifier' => 'OTH', 'name' => 'Other' }]
        )
        @other_channel = @other_server.channels.create!(name: 'elsewhere')
        @other_message = @other_channel.messages.create!(body: 'root', user: users(:two))
        @other_project_link = MtasksLink.create!(
          link_type: MtasksLink::PROJECT_CHANNEL,
          server_integration: @other_integration, channel: @other_channel,
          mtasks_team_id: 31, mtasks_project_id: 8,
          created_by_user: users(:two)
        )
      end

      # ---- issue.created ----

      test 'issue.created creates cache + posts message into project channel' do
        delivery = build_delivery(event: 'issue.created', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'project_id' => 7, 'team_id' => 21,
                                    'title' => 'fix login flow', 'creator_user_id' => 5001
                                  })

        assert_difference -> { MtasksIssueCache.count } => 1, -> { Message.count } => 1 do
          result = ProcessIssue.call(delivery: delivery)
          assert result.ok, result.error
        end

        message = Message.last
        assert message.system?
        assert_equal 'mtasks', message.data['source']
        assert_equal 'issue.created', message.data['event_type']
        assert_equal 91, message.data['mtasks_issue_id']
        assert_equal @channel.id, message.channel_id
        assert_match 'HOUR-91', message.body
        assert_match 'fix login flow', message.body
        # users(:one) is mapped to mtasks_user_id 5001 via the fixture
        assert_match '@userone', message.body
      end

      test 'issue.created skipped when no project_channel link exists' do
        @link.destroy

        delivery = build_delivery(event: 'issue.created', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'project_id' => 7, 'team_id' => 21
                                  })

        assert_no_difference 'Message.count' do
          result = ProcessIssue.call(delivery: delivery)
          assert result.ok # not an error — just no destination
        end
        assert_equal 1, MtasksIssueCache.where(mtasks_issue_id: 91).count # still cached
      end

      test "issue.created skipped when channel pref is 'off'" do
        @channel.update!(settings: { 'mtasks_system_messages' => 'off' })

        delivery = build_delivery(event: 'issue.created', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'project_id' => 7, 'team_id' => 21
                                  })

        assert_no_difference 'Message.count' do
          result = ProcessIssue.call(delivery: delivery)
          assert result.ok
        end
      end

      test "issue.created skipped when channel pref is 'status_only'" do
        @channel.update!(settings: { 'mtasks_system_messages' => 'status_only' })

        delivery = build_delivery(event: 'issue.created', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'project_id' => 7, 'team_id' => 21
                                  })

        assert_no_difference 'Message.count' do
          ProcessIssue.call(delivery: delivery)
        end
      end

      # ---- issue.updated ----

      test 'issue.updated upserts cache without posting' do
        delivery = build_delivery(event: 'issue.updated', data: {
                                    'id' => 91, 'identifier' => 'HOUR-91',
                                    'title' => 'updated title',
                                    'lane' => { 'id' => 14, 'name' => 'In Progress' },
                                    'project' => { 'id' => 7, 'name' => 'Roadmap' },
                                    'priority' => 'high'
                                  })

        assert_no_difference 'Message.count' do
          assert_difference 'MtasksIssueCache.count', 1 do
            result = ProcessIssue.call(delivery: delivery)
            assert result.ok
          end
        end

        cache = MtasksIssueCache.find_by(mtasks_issue_id: 91)
        assert_equal 'In Progress', cache.status_name
        assert_equal 14, cache.lane_id
        assert_equal 'high', cache.priority
      end

      # ---- issue.status_changed ----

      test 'issue.status_changed posts a system message using the cached issue' do
        # Pre-populate the cache (typical flow: created landed first)
        MtasksIssueCache.create!(
          mtasks_issue_id: 91, identifier: 'HOUR-91', title: 'fix login',
          payload: { 'project_id' => 7 }, last_synced_at: Time.current
        )

        delivery = build_delivery(event: 'issue.status_changed', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'from_lane_id' => 13, 'from_lane_name' => 'Backlog',
                                    'to_lane_id' => 14, 'to_lane_name' => 'In Progress',
                                    'actor_user_id' => 5001
                                  })

        assert_difference 'Message.count', 1 do
          result = ProcessIssue.call(delivery: delivery)
          assert result.ok, result.error
        end

        message = Message.last
        assert_match 'Backlog', message.body
        assert_match 'In Progress', message.body
        # cache row should be updated with new lane info
        cache = MtasksIssueCache.find_by(mtasks_issue_id: 91)
        assert_equal 14, cache.lane_id
        assert_equal 'In Progress', cache.status_name
      end

      test 'issue.status_changed posts as a thread reply when issue_thread link exists' do
        MtasksIssueCache.create!(
          mtasks_issue_id: 91, identifier: 'HOUR-91',
          payload: { 'project_id' => 7 }, last_synced_at: Time.current
        )
        parent = messages(:one)
        MtasksLink.create!(
          link_type: MtasksLink::ISSUE_THREAD,
          server_integration: @integration, thread: parent,
          mtasks_team_id: 21, mtasks_issue_id: 91,
          created_by_user: users(:one)
        )

        delivery = build_delivery(event: 'issue.status_changed', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'from_lane_name' => 'Backlog', 'to_lane_name' => 'In Progress'
                                  })

        ProcessIssue.call(delivery: delivery)
        assert_equal parent.id, Message.last.parent_message_id
      end

      test 'issue.status_changed cache miss + Jait::Fetcher backfill' do
        remote_issue = {
          'id' => 91, 'identifier' => 'HOUR-91', 'title' => 'fix',
          'project' => { 'id' => 7 }, 'lane' => { 'id' => 14, 'name' => 'In Progress' }
        }

        delivery = build_delivery(event: 'issue.status_changed', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'from_lane_name' => 'Backlog', 'to_lane_name' => 'In Progress'
                                  })

        with_stubbed_class_method(Jait::Fetcher, :call, remote_issue) do
          assert_difference 'Message.count', 1 do
            assert_difference 'MtasksIssueCache.count', 1 do
              result = ProcessIssue.call(delivery: delivery)
              assert result.ok, result.error
            end
          end
        end
      end

      test 'issue.status_changed errors when cache miss + Jait::Fetcher returns nil' do
        delivery = build_delivery(event: 'issue.status_changed', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'from_lane_name' => 'Backlog', 'to_lane_name' => 'In Progress'
                                  })

        with_stubbed_class_method(Jait::Fetcher, :call, nil) do
          assert_no_difference 'Message.count' do
            result = ProcessIssue.call(delivery: delivery)
            assert_not result.ok
            assert_match(/not in cache/, result.error)
          end
        end
      end

      # ---- issue.assigned ----

      test 'issue.assigned posts assignment message' do
        MtasksIssueCache.create!(
          mtasks_issue_id: 91, identifier: 'HOUR-91',
          payload: { 'project_id' => 7 }, last_synced_at: Time.current
        )

        delivery = build_delivery(event: 'issue.assigned', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'assignee_user_id' => 5002, 'assignee_email' => 'two@example.com',
                                    'actor_user_id' => 5001
                                  })

        assert_difference 'Message.count', 1 do
          ProcessIssue.call(delivery: delivery)
        end

        body = Message.last.body
        assert_match '@two', body
        assert_match '@userone', body # actor mapped from mtasks_user_id 5001
        # cache row updated
        assert_equal 'two@example.com', MtasksIssueCache.find_by(mtasks_issue_id: 91).assignee_email
      end

      # ---- loop guard ----

      test 'inbound issue events do not enqueue MtasksOutboundEmitterJob' do
        delivery = build_delivery(event: 'issue.created', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'project_id' => 7, 'team_id' => 21, 'title' => 't'
                                  })

        assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
          ProcessIssue.call(delivery: delivery)
        end
      end

      # ---- cache busting ----

      test 'busts both Jait::Fetcher cache keys after issue.updated' do
        Rails.cache.write("jait:#{@integration.id}:t21:issue:91", { 'id' => 91 })
        Rails.cache.write("jait:#{@integration.id}:t21:issue:ident:HOUR-91", { 'id' => 91 })

        delivery = build_delivery(event: 'issue.updated', data: {
                                    'id' => 91, 'identifier' => 'HOUR-91',
                                    'project' => { 'id' => 7 },
                                    'lane' => { 'id' => 14, 'name' => 'In Progress' }
                                  })

        ProcessIssue.call(delivery: delivery)
        assert_nil Rails.cache.read("jait:#{@integration.id}:t21:issue:91")
        assert_nil Rails.cache.read("jait:#{@integration.id}:t21:issue:ident:HOUR-91")
      end

      # ---- cross-server isolation ----

      test 'rejects delivery with no signing integration' do
        delivery = build_delivery(integration: nil, event: 'issue.created', data: {
                                    'issue_id' => 91, 'identifier' => 'HOUR-91',
                                    'project_id' => 7, 'team_id' => 21
                                  })

        assert_no_difference -> { MtasksIssueCache.count } => 0, -> { Message.count } => 0 do
          result = ProcessIssue.call(delivery: delivery)
          assert_not result.ok
          assert_match(/no enabled integration/, result.error)
        end
      end

      test 'issue.created rejects a team outside the signing integration' do
        build_other_server

        delivery = build_delivery(event: 'issue.created', data: {
                                    'issue_id' => 92, 'identifier' => 'OTH-92',
                                    'project_id' => 8, 'team_id' => 31
                                  })

        with_stubbed_instance_method(Jait::ApiClient, :discover_teams!,
                                     [{ 'id' => 21, 'identifier' => 'HOUR', 'name' => 'Hourglass' }]) do
          assert_no_difference -> { MtasksIssueCache.count } => 0, -> { Message.count } => 0 do
            result = ProcessIssue.call(delivery: delivery)
            assert_not result.ok
            assert_match(/team 31 not in integration/, result.error)
          end
        end
      end

      test 'issue.created does not post into a project channel on another server' do
        build_other_server

        delivery = build_delivery(event: 'issue.created', data: {
                                    'issue_id' => 92, 'identifier' => 'HOUR-92',
                                    'project_id' => 8, 'team_id' => 21 # project 8 is linked on the other server
                                  })

        assert_no_difference -> { @other_channel.messages.count } do
          result = ProcessIssue.call(delivery: delivery)
          assert result.ok, result.error
        end
      end

      test 'issue.status_changed does not reply in a thread on another server' do
        build_other_server
        MtasksLink.create!(
          link_type: MtasksLink::ISSUE_THREAD,
          server_integration: @other_integration, thread: @other_message,
          mtasks_team_id: 31, mtasks_issue_id: 92,
          created_by_user: users(:two)
        )
        MtasksIssueCache.create!(
          mtasks_issue_id: 92, identifier: 'OTH-92', title: 'theirs',
          payload: { 'project_id' => 8 }, last_synced_at: Time.current
        )

        delivery = build_delivery(event: 'issue.status_changed', data: {
                                    'issue_id' => 92, 'identifier' => 'OTH-92',
                                    'to_lane_id' => 14, 'to_lane_name' => 'In Progress'
                                  })

        assert_no_difference -> { Message.count } do
          ProcessIssue.call(delivery: delivery)
        end
      end

      test 'cache backfill only probes the signing integration' do
        build_other_server
        probed = []
        original = Jait::Fetcher.method(:call)
        Jait::Fetcher.define_singleton_method(:call) do |integration:, **|
          probed << integration.id
          nil
        end

        delivery = build_delivery(event: 'issue.assigned', data: {
                                    'issue_id' => 93, 'identifier' => 'HOUR-93', 'assignee_email' => 'a@b.c'
                                  })
        result = ProcessIssue.call(delivery: delivery)

        assert_not result.ok
        assert_equal [@integration.id], probed.uniq
      ensure
        Jait::Fetcher.define_singleton_method(:call, original)
      end
    end
  end
end
