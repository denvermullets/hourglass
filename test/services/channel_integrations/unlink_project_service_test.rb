require 'test_helper'

module ChannelIntegrations
  class UnlinkProjectServiceTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @integration = server_integrations(:jait_one)
      @channel = channels(:general)
      @user = users(:one)
    end

    test 'destroys the link and enqueues link.removed' do
      link = MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: @integration,
        channel: @channel,
        mtasks_team_id: 21,
        mtasks_project_id: 7,
        created_by_user: @user
      )

      assert_difference 'MtasksLink.count', -1 do
        assert_enqueued_with(job: MtasksOutboundEmitterJob) do
          result = UnlinkProjectService.call(channel: @channel, user: @user)
          assert result.ok
        end
      end

      assert_raises(ActiveRecord::RecordNotFound) { link.reload }
    end

    test 'is a no-op when no link exists' do
      assert_no_difference 'MtasksLink.count' do
        assert_no_enqueued_jobs do
          result = UnlinkProjectService.call(channel: @channel, user: @user)
          assert result.ok
        end
      end
    end
  end
end
