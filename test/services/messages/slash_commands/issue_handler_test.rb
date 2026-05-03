require 'test_helper'

module Messages
  module SlashCommands
    class IssueHandlerTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        @channel = channels(:general)
        @user = users(:one)
        @integration = server_integrations(:jait_one)
        @integration.update!(discovered_teams: [{ 'id' => 21, 'identifier' => 'HOUR', 'name' => 'Hourglass' }])
      end

      def link_channel!
        MtasksLink.create!(
          link_type: MtasksLink::PROJECT_CHANNEL,
          server_integration: @integration, channel: @channel,
          mtasks_team_id: 21, mtasks_project_id: 7,
          created_by_user: @user
        )
      end

      def stub_create_issue(value, &)
        with_stubbed_instance_method(Jait::ApiClient, :create_issue, ->(**_kw) { value }, &)
      end

      test 'creates card message + issue_thread link on success' do
        link_channel!
        issue = { 'id' => 9001, 'identifier' => 'HOUR-9001', 'title' => 'Test from chat' }

        stub_create_issue(issue) do
          assert_difference 'Message.count', 1 do
            assert_difference 'MtasksLink.count', 1 do
              result = IssueHandler.call(
                channel: @channel, user: @user, args: 'Test from chat'
              )
              assert result.ok
              msg = result.message
              assert msg.regular?
              assert_nil msg.parent_message_id
              assert_equal 'issue_card', msg.data['kind']
              assert_equal 9001, msg.data['issue']['id']
            end
          end
        end

        link = MtasksLink.last
        assert link.issue_thread?
        assert_equal 9001, link.mtasks_issue_id
        assert_equal 21, link.mtasks_team_id
      end

      test 'card creation skips outbound emitter (data[source] = mtasks)' do
        link_channel!
        issue = { 'id' => 9001, 'identifier' => 'HOUR-9001', 'title' => 'Test' }

        stub_create_issue(issue) do
          assert_no_enqueued_jobs(only: MtasksOutboundEmitterJob) do
            # CreateService is what enqueues; here we exercise the handler in isolation.
            # Verify by re-running through CreateService instead:
            Messages::CreateService.call(
              channel: @channel, user: @user,
              params: { body: '<p>/issue Test</p>' }
            )
          end
        end
      end

      test 'channel not linked posts a system message and makes no API call' do
        called = false
        with_stubbed_instance_method(Jait::ApiClient, :create_issue, lambda { |**_kw|
          called = true
          {}
        }) do
          assert_difference 'Message.count', 1 do
            assert_no_difference 'MtasksLink.count' do
              result = IssueHandler.call(
                channel: @channel, user: @user, args: 'Foo'
              )
              assert_not result.ok
              assert result.message.system?
              assert_match(/isn't linked/, result.message.body)
            end
          end
        end
        assert_not called, 'create_issue should not be called when channel is unlinked'
      end

      test 'empty title posts a usage system message and makes no API call' do
        link_channel!
        called = false
        with_stubbed_instance_method(Jait::ApiClient, :create_issue, lambda { |**_kw|
          called = true
          {}
        }) do
          assert_difference 'Message.count', 1 do
            assert_no_difference 'MtasksLink.count' do
              result = IssueHandler.call(channel: @channel, user: @user, args: '')
              assert_not result.ok
              assert result.message.system?
              assert_match(/Usage:/, result.message.body)
            end
          end
        end
        assert_not called
      end

      test 'API error posts an error system message and creates no link' do
        link_channel!

        with_stubbed_instance_method(Jait::ApiClient, :create_issue,
                                     ->(**_kw) { raise Jait::ApiClient::Error, 'boom' }) do
          assert_difference 'Message.count', 1 do
            assert_no_difference 'MtasksLink.count' do
              result = IssueHandler.call(channel: @channel, user: @user, args: 'Foo')
              assert_not result.ok
              assert result.message.system?
              assert_match(/Failed to create issue: boom/, result.message.body)
            end
          end
        end
      end

      test 'passes user.email_address as creator to the API' do
        link_channel!
        captured = {}
        with_stubbed_instance_method(Jait::ApiClient, :create_issue,
                                     lambda { |**kw|
                                       captured.merge!(kw)
                                       { 'id' => 1, 'identifier' => 'X-1', 'title' => 'T' }
                                     }) do
          IssueHandler.call(channel: @channel, user: @user, args: 'Title here')
        end
        assert_equal @user.email_address, captured[:creator]
        assert_equal 'Title here', captured[:title]
        assert_equal 21, captured[:team_id]
        assert_equal 7, captured[:project_id]
      end

      private

      def with_stubbed_instance_method(klass, method_name, callable)
        alias_target = :"_stubbed_orig_#{method_name}"
        klass.alias_method(alias_target, method_name)
        klass.define_method(method_name) { |**kw| callable.call(**kw) }
        yield
      ensure
        klass.alias_method(method_name, alias_target)
        klass.send(:remove_method, alias_target)
      end
    end
  end
end
