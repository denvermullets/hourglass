module ChannelIntegrations
  class LinkProjectService < Service
    Result = Struct.new(:ok, :link, :error, keyword_init: true)

    def initialize(channel:, integration:, team_id:, project_id:, user:)
      @channel = channel
      @integration = integration
      @team_id = team_id.to_i
      @project_id = project_id.to_i
      @user = user
    end

    def call
      return error('integration not configured') unless @integration&.configured?
      return error('team not in this integration') unless @integration.team_for(@team_id)

      project = Jait::Fetcher.call(integration: @integration, kind: 'project',
                                   team_id: @team_id, id: @project_id)
      return error('project not found in mtasks') if project.nil?

      link = create_link
      enqueue_outbound(link)
      ChannelIntegrations::BroadcastLinkStateService.call(channel: @channel)
      Result.new(ok: true, link: link)
    rescue ActiveRecord::RecordInvalid => e
      error(e.record.errors.full_messages.to_sentence)
    end

    private

    def create_link
      MtasksLink.create!(
        link_type: MtasksLink::PROJECT_CHANNEL,
        server_integration: @integration,
        channel: @channel,
        mtasks_team_id: @team_id,
        mtasks_project_id: @project_id,
        created_by_user: @user
      )
    end

    def enqueue_outbound(link)
      MtasksOutboundEmitterJob.perform_later(
        integration_id: @integration.id,
        event_type: 'link.created',
        data: {
          link_type: 'project_channel',
          mtasks_project_id: link.mtasks_project_id,
          hourglass_channel_id: @channel.id,
          created_by_user_id: @user.id
        }
      )
    end

    def error(msg)
      Result.new(ok: false, error: msg)
    end
  end
end
