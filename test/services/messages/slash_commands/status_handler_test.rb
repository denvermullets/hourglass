require 'test_helper'

module Messages
  module SlashCommands
    class StatusHandlerTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        @channel = channels(:general)
        @user = users(:one)
        @integration = server_integrations(:jait_one)
        @integration.update!(discovered_teams: [{ 'id' => 21, 'identifier' => 'HOUR', 'name' => 'Hourglass' }])
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

      test 'happy path calls update_issue_status and posts confirmation in thread' do
        link_thread!
        captured = {}
        with_stubbed_instance_method(Jait::ApiClient, :update_issue_status, lambda { |**kw|
          captured.merge!(kw)
          { 'id' => 9001, 'status' => 'done' }
        }) do
          result = StatusHandler.call(
            channel: @channel, user: @user, args: 'done',
            parent_message_id: @parent.id
          )
          assert result.ok
          msg = result.message
          assert msg.system?
          assert_equal @parent.id, msg.parent_message_id
          assert_match(/Status set to done on HOUR-9001/, msg.body)
        end
        assert_equal 21, captured[:team_id]
        assert_equal 9001, captured[:issue_id]
        assert_equal 'done', captured[:status]
      end

      test 'forwards arbitrary keywords to the API as-typed (downcased)' do
        link_thread!
        captured = {}
        with_stubbed_instance_method(Jait::ApiClient, :update_issue_status, lambda { |**kw|
          captured.merge!(kw)
          { 'id' => 9001 }
        }) do
          StatusHandler.call(
            channel: @channel, user: @user, args: 'In_Review',
            parent_message_id: @parent.id
          )
        end
        assert_equal 'in_review', captured[:status]
      end

      test 'no args posts usage system message and makes no API call' do
        link_thread!
        called = false
        with_stubbed_instance_method(Jait::ApiClient, :update_issue_status, lambda { |**_kw|
          called = true
          {}
        }) do
          result = StatusHandler.call(
            channel: @channel, user: @user, args: '',
            parent_message_id: @parent.id
          )
          assert_not result.ok
          assert_match(/Usage:/, result.message.body)
        end
        assert_not called
      end

      test 'not in a thread posts a system message and makes no API call' do
        link_thread!
        called = false
        with_stubbed_instance_method(Jait::ApiClient, :update_issue_status, lambda { |**_kw|
          called = true
          {}
        }) do
          result = StatusHandler.call(channel: @channel, user: @user, args: 'done')
          assert_not result.ok
          assert_match(/inside a thread/, result.message.body)
        end
        assert_not called
      end

      test 'thread not linked posts a system message and makes no API call' do
        called = false
        with_stubbed_instance_method(Jait::ApiClient, :update_issue_status, lambda { |**_kw|
          called = true
          {}
        }) do
          result = StatusHandler.call(
            channel: @channel, user: @user, args: 'done',
            parent_message_id: @parent.id
          )
          assert_not result.ok
          assert_match(/isn't linked/, result.message.body)
        end
        assert_not called
      end

      test 'API error surfaces in a system message' do
        link_thread!
        with_stubbed_instance_method(Jait::ApiClient, :update_issue_status,
                                     ->(**_kw) { raise Jait::ApiClient::Error, 'unknown lane: nope' }) do
          result = StatusHandler.call(
            channel: @channel, user: @user, args: 'nope',
            parent_message_id: @parent.id
          )
          assert_not result.ok
          assert_match(/Failed to update status: unknown lane: nope/, result.message.body)
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
