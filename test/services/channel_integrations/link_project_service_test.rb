require 'test_helper'

module ChannelIntegrations
  class LinkProjectServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @integration = server_integrations(:jait_one)
      @integration.update!(discovered_teams: [{ 'id' => 21, 'identifier' => 'HOUR', 'name' => 'Hourglass' }])
      @channel = channels(:general)
      @user = users(:one)
      @team_id = 21
      @project_id = 7
    end

    def stub_fetcher(return_value, &)
      with_stubbed_class_method(Jait::Fetcher, :call, return_value, &)
    end

    test 'happy path creates a project_channel link and enqueues link.created' do
      stub_fetcher({ 'id' => @project_id, 'name' => 'Roadmap' }) do
        assert_difference 'MtasksLink.count', 1 do
          assert_enqueued_with(job: MtasksOutboundEmitterJob) do
            result = LinkProjectService.call(
              channel: @channel, integration: @integration,
              team_id: @team_id, project_id: @project_id, user: @user
            )
            assert result.ok
          end
        end
      end

      link = MtasksLink.last
      assert link.project_channel?
      assert_equal @channel.id, link.channel_id
      assert_equal @team_id, link.mtasks_team_id
      assert_equal @project_id, link.mtasks_project_id
      assert_equal @user.id, link.created_by_user_id
    end

    test 'fails when integration is not configured' do
      @integration.update_columns(api_token: nil, discovered_teams: [])
      result = LinkProjectService.call(
        channel: @channel, integration: @integration,
        team_id: @team_id, project_id: @project_id, user: @user
      )
      assert_not result.ok
      assert_match(/not configured/, result.error)
    end

    test 'fails when team_id is not in the discovered teams' do
      result = LinkProjectService.call(
        channel: @channel, integration: @integration,
        team_id: 9999, project_id: @project_id, user: @user
      )
      assert_not result.ok
      assert_match(/team not in this integration/, result.error)
    end

    test 'fails when the project is not found in mtasks' do
      stub_fetcher(nil) do
        result = LinkProjectService.call(
          channel: @channel, integration: @integration,
          team_id: @team_id, project_id: @project_id, user: @user
        )
        assert_not result.ok
        assert_match(/not found/, result.error)
      end
    end

    test 'fails when the channel is already linked (unique partial index)' do
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: @integration,
        channel: @channel,
        mtasks_team_id: @team_id,
        mtasks_project_id: 99,
        created_by_user: @user
      )

      stub_fetcher({ 'id' => @project_id, 'name' => 'Other' }) do
        assert_no_difference 'MtasksLink.count' do
          assert_raises(ActiveRecord::RecordNotUnique) do
            LinkProjectService.call(
              channel: @channel, integration: @integration,
              team_id: @team_id, project_id: @project_id, user: @user
            )
          end
        end
      end
    end
  end
end
