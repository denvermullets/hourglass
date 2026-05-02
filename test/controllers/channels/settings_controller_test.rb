require 'test_helper'

module Channels
  class SettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @server = servers(:one)
      @channel = channels(:general)
      @integration = server_integrations(:jait_one)
      @integration.update!(discovered_teams: [{ 'id' => 21, 'identifier' => 'HOUR', 'name' => 'Hourglass' }])
      sign_in_as(users(:one)) # owner = moderator
    end

    def stub_fetcher(return_value, &)
      with_stubbed_class_method(Jait::Fetcher, :call, return_value, &)
    end

    # Replaces ServerIntegration#client for the duration of the block — used to
    # exercise the controller's `mtasks_projects` action without real HTTP.
    def with_fake_client(fake)
      original = ServerIntegration.instance_method(:client)
      ServerIntegration.define_method(:client) { fake }
      yield
    ensure
      ServerIntegration.define_method(:client, original)
    end

    # ---- show ----

    test 'show renders unlinked state by default' do
      get server_channel_settings_path(@server, @channel)
      assert_response :success
      assert_match(/no project linked yet/i, response.body)
    end

    test 'show renders linked state when a link exists and the project resolves' do
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: @integration, channel: @channel,
        mtasks_team_id: 21, mtasks_project_id: 7,
        created_by_user: users(:one)
      )

      stub_fetcher({ 'id' => 7, 'name' => 'Roadmap', 'identifier' => 'HOUR-PRJ-7' }) do
        get server_channel_settings_path(@server, @channel)
      end
      assert_response :success
      assert_match(/Roadmap/, response.body)
      assert_match(/HOUR-PRJ-7/, response.body)
    end

    test 'show renders broken state when the linked project no longer resolves' do
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: @integration, channel: @channel,
        mtasks_team_id: 21, mtasks_project_id: 7,
        created_by_user: users(:one)
      )

      stub_fetcher(nil) do
        get server_channel_settings_path(@server, @channel)
      end
      assert_response :success
      assert_match(/project not found in mtasks/i, response.body)
    end

    test 'show renders no_integration state when no enabled integration exists' do
      @integration.update!(enabled: false)
      get server_channel_settings_path(@server, @channel)
      assert_response :success
      assert_match(/no JAIT integration is enabled/i, response.body)
    end

    test 'show requires server membership' do
      sign_out
      sign_in_as(users(:two))
      other_server = servers(:two)
      other_channel = other_server.channels.create!(name: 'general', channel_type: :text, position: 0)

      sign_out
      sign_in_as(users(:one)) # not a member of servers(:two)
      get server_channel_settings_path(other_server, other_channel)
      assert_redirected_to servers_path
    end

    # ---- mtasks_projects ----

    test 'mtasks_projects returns filtered JSON list' do
      fake = Class.new do
        def fetch_projects(_team_id)
          [
            { 'id' => 1, 'name' => 'Alpha',  'identifier' => 'A', 'description' => 'a desc' },
            { 'id' => 2, 'name' => 'Bravo',  'identifier' => 'B', 'description' => 'b desc' },
            { 'id' => 3, 'name' => 'Browse', 'identifier' => 'C', 'description' => '' }
          ]
        end
      end.new

      with_fake_client(fake) do
        get mtasks_projects_server_channel_settings_path(@server, @channel),
            params: { team_id: 21, q: 'br' }
      end

      assert_response :success
      body = JSON.parse(response.body)
      ids = body.map { |p| p['id'] }
      assert_includes ids, 2
      assert_includes ids, 3
      assert_not_includes ids, 1
    end

    test 'mtasks_projects returns empty array when no integration' do
      @integration.update!(enabled: false)
      get mtasks_projects_server_channel_settings_path(@server, @channel), params: { team_id: 21 }
      assert_response :success
      assert_equal [], JSON.parse(response.body)
    end

    test 'mtasks_projects returns 502 on Jait::ApiClient::Error' do
      fake = Class.new do
        def fetch_projects(_team_id)
          raise Jait::ApiClient::Error, 'boom'
        end
      end.new

      with_fake_client(fake) do
        get mtasks_projects_server_channel_settings_path(@server, @channel), params: { team_id: 21 }
      end
      assert_response :bad_gateway
    end

    # ---- link_project ----

    test 'link_project creates the link and enqueues outbound' do
      stub_fetcher({ 'id' => 7, 'name' => 'Roadmap' }) do
        assert_difference 'MtasksLink.count', 1 do
          assert_enqueued_with(job: MtasksOutboundEmitterJob) do
            post link_project_server_channel_settings_path(@server, @channel),
                 params: { team_id: 21, project_id: 7 }
          end
        end
      end
      assert_redirected_to server_channel_settings_path(@server, @channel)
      assert_equal 'Channel linked.', flash[:notice]
    end

    test 'link_project rejects non-moderators' do
      sign_out
      sign_in_as(users(:two)) # member but not moderator on servers(:one)

      stub_fetcher({ 'id' => 7, 'name' => 'Roadmap' }) do
        assert_no_difference 'MtasksLink.count' do
          post link_project_server_channel_settings_path(@server, @channel),
               params: { team_id: 21, project_id: 7 }
        end
      end
    end

    test 'link_project surfaces alert when project is not found' do
      stub_fetcher(nil) do
        assert_no_difference 'MtasksLink.count' do
          post link_project_server_channel_settings_path(@server, @channel),
               params: { team_id: 21, project_id: 7 }
        end
      end
      assert_redirected_to server_channel_settings_path(@server, @channel)
      assert_match(/not found/i, flash[:alert])
    end

    # ---- unlink_project ----

    test 'unlink_project removes the link and enqueues outbound' do
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: @integration, channel: @channel,
        mtasks_team_id: 21, mtasks_project_id: 7,
        created_by_user: users(:one)
      )

      assert_difference 'MtasksLink.count', -1 do
        assert_enqueued_with(job: MtasksOutboundEmitterJob) do
          delete link_project_server_channel_settings_path(@server, @channel)
        end
      end
      assert_redirected_to server_channel_settings_path(@server, @channel)
      assert_equal 'Channel unlinked.', flash[:notice]
    end
  end
end
