module ChannelIntegrations
  class BroadcastLinkStateService < Service
    def initialize(channel:)
      @channel = channel
    end

    def call
      @channel.association(:mtasks_project_link).reset
      broadcast_badge
      broadcast_panel
    end

    private

    def broadcast_badge
      Turbo::StreamsChannel.broadcast_replace_to(
        @channel,
        target: "channel_#{@channel.id}_jait_linked_badge",
        partial: 'channels/jait_linked_badge',
        locals: { channel: @channel }
      )
    end

    def broadcast_panel
      integration = resolve_integration
      link = @channel.mtasks_project_link
      link_state, linked_project = resolve_link_state(link, integration)

      Turbo::StreamsChannel.broadcast_replace_to(
        @channel,
        target: "channel_#{@channel.id}_jait_link_panel",
        partial: 'channels/settings/jait_link_panel',
        locals: {
          server: @channel.server,
          channel: @channel,
          integration: integration,
          link: link,
          link_state: link_state,
          linked_project: linked_project
        }
      )
    end

    def resolve_integration
      @channel.server.server_integrations
              .enabled
              .for_kind(ServerIntegration::KIND_JAIT)
              .first
    end

    def resolve_link_state(link, integration)
      return [:no_integration, nil] unless integration
      return [:unlinked, nil] unless link

      project = Jait::Fetcher.call(integration: integration, kind: 'project',
                                   team_id: link.mtasks_team_id, id: link.mtasks_project_id)
      project ? [:linked, project] : [:broken, nil]
    end
  end
end
