require 'test_helper'

module Messages
  module SlashCommands
    class LinkHandlerTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
      include ActiveJob::TestHelper

      setup do
        @channel = channels(:general)
        @user = users(:one)
        @integration = server_integrations(:jait_one)
        @integration.update!(discovered_teams: [{ 'id' => 21, 'identifier' => 'HOUR', 'name' => 'Hourglass' }])
        @parent = @channel.messages.create!(user: @user, message_type: :regular, body: 'thread root')
      end

      def link_channel!
        MtasksLink.create!(
          link_type: MtasksLink::PROJECT_CHANNEL,
          server_integration: @integration, channel: @channel,
          mtasks_team_id: 21, mtasks_project_id: 7,
          created_by_user: @user
        )
      end

      def stub_fetch(value, &)
        with_stubbed_instance_method(Jait::ApiClient, :fetch_issue_by_identifier, ->(*_args) { value }, &)
      end

      test 'happy path creates link, card message in thread, and enqueues link.created' do # rubocop:disable Metrics/BlockLength
        link_channel!
        issue = { 'id' => 9001, 'identifier' => 'HOUR-9001', 'title' => 'Existing issue' }

        stub_fetch(issue) do
          assert_enqueued_jobs 1, only: MtasksOutboundEmitterJob do
            assert_difference 'Message.count', 1 do
              assert_difference 'MtasksLink.issue_threads.count', 1 do
                result = LinkHandler.call(
                  channel: @channel, user: @user, args: 'HOUR-9001',
                  parent_message_id: @parent.id
                )
                assert result.ok
                msg = result.message
                assert msg.regular?
                assert_equal @parent.id, msg.parent_message_id
                assert_equal 'issue_card', msg.data['kind']
                assert_equal 9001, msg.data['issue']['id']
              end
            end
          end
        end

        args = enqueued_jobs.last[:args].first
        assert_equal 'link.created', args['event_type']
        assert_equal 'issue_thread', args['data']['link_type']
        assert_equal 9001, args['data']['mtasks_issue_id']
        assert_equal @parent.id, args['data']['hourglass_thread_id']

        link = MtasksLink.issue_threads.last
        assert_equal @parent.id, link.thread_id
        assert_equal 9001, link.mtasks_issue_id
        assert_equal 'HOUR-9001', link.mtasks_issue_identifier
      end

      test 'missing identifier posts usage system message and makes no API call' do
        link_channel!
        called = false
        with_stubbed_instance_method(Jait::ApiClient, :fetch_issue_by_identifier, lambda { |*_args|
          called = true
          nil
        }) do
          assert_no_difference 'MtasksLink.issue_threads.count' do
            result = LinkHandler.call(
              channel: @channel, user: @user, args: '',
              parent_message_id: @parent.id
            )
            assert_not result.ok
            assert result.message.system?
            assert_match(/Usage:/, result.message.body)
          end
        end
        assert_not called
      end

      test 'not in a thread posts a system message and makes no API call' do
        link_channel!
        called = false
        with_stubbed_instance_method(Jait::ApiClient, :fetch_issue_by_identifier, lambda { |*_args|
          called = true
          nil
        }) do
          assert_no_difference 'MtasksLink.issue_threads.count' do
            result = LinkHandler.call(channel: @channel, user: @user, args: 'HOUR-9001')
            assert_not result.ok
            assert result.message.system?
            assert_match(/inside a thread/, result.message.body)
          end
        end
        assert_not called
      end

      test 'channel not linked posts a system message' do
        result = LinkHandler.call(
          channel: @channel, user: @user, args: 'HOUR-9001',
          parent_message_id: @parent.id
        )
        assert_not result.ok
        assert_match(/isn't linked/, result.message.body)
      end

      test 'thread already linked posts a system message and creates no new link' do
        link_channel!
        MtasksLink.create!(
          link_type: MtasksLink::ISSUE_THREAD,
          server_integration: @integration, thread: @parent,
          mtasks_issue_id: 1, mtasks_team_id: 21,
          created_by_user: @user
        )
        called = false
        with_stubbed_instance_method(Jait::ApiClient, :fetch_issue_by_identifier, lambda { |*_args|
          called = true
          nil
        }) do
          assert_no_difference 'MtasksLink.issue_threads.count' do
            result = LinkHandler.call(
              channel: @channel, user: @user, args: 'HOUR-9001',
              parent_message_id: @parent.id
            )
            assert_not result.ok
            assert_match(/already linked/, result.message.body)
          end
        end
        assert_not called
      end

      test 'identifier not found posts a system message' do
        link_channel!
        stub_fetch(nil) do
          assert_no_difference 'MtasksLink.issue_threads.count' do
            result = LinkHandler.call(
              channel: @channel, user: @user, args: 'HOUR-404',
              parent_message_id: @parent.id
            )
            assert_not result.ok
            assert_match(/HOUR-404 not found/, result.message.body)
          end
        end
      end

      test 'API error posts a system message and creates no link' do
        link_channel!
        with_stubbed_instance_method(Jait::ApiClient, :fetch_issue_by_identifier,
                                     ->(*_args) { raise Jait::ApiClient::Error, 'boom' }) do
          assert_no_difference 'MtasksLink.issue_threads.count' do
            result = LinkHandler.call(
              channel: @channel, user: @user, args: 'HOUR-9001',
              parent_message_id: @parent.id
            )
            assert_not result.ok
            assert_match(/Failed to look up issue: boom/, result.message.body)
          end
        end
      end

      private

      def with_stubbed_instance_method(klass, method_name, callable)
        alias_target = :"_stubbed_orig_#{method_name}"
        klass.alias_method(alias_target, method_name)
        klass.define_method(method_name) { |*args, **kw| callable.call(*args, **kw) }
        yield
      ensure
        klass.alias_method(method_name, alias_target)
        klass.send(:remove_method, alias_target)
      end
    end
  end
end
