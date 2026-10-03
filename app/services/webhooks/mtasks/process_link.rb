module Webhooks
  module Mtasks
    class ProcessLink < Service
      Result = Struct.new(:ok, :link, :error, keyword_init: true)

      def initialize(delivery:)
        @delivery = delivery
        @event = delivery.event_type
        @data = delivery.payload['data'] || {}
        @integration = delivery.server_integration
      end

      def call
        return error('no enabled integration') unless integration_usable?

        case [@event, @data['link_type']]
        when ['link.created', MtasksLink::PROJECT_CHANNEL] then create_project_channel
        when ['link.created', MtasksLink::ISSUE_THREAD]    then create_issue_thread
        when ['link.removed', MtasksLink::PROJECT_CHANNEL] then remove_project_channel
        when ['link.removed', MtasksLink::ISSUE_THREAD]    then remove_issue_thread
        else error("unhandled #{@event}/#{@data['link_type']}")
        end
      end

      private

      # ---- handlers ----
      #
      # Every lookup is scoped to the server of the integration that signed the
      # delivery, so a payload signed by server A can never touch server B.

      def create_project_channel
        channel = find_channel
        return error('channel not found') unless channel

        project_id = @data['mtasks_project_id'].presence
        return error('mtasks_project_id missing') unless project_id

        payload_team_id = @data['mtasks_team_id'].presence
        return foreign_team_error(payload_team_id) if payload_team_id && !@integration.knows_team?(payload_team_id)

        team_id = resolve_with_refresh(project_id: project_id)
        return error('team not resolvable') unless team_id

        link = upsert_project_link(channel, project_id, team_id)
        Result.new(ok: true, link: link)
      end

      def create_issue_thread
        issue_id = @data['mtasks_issue_id'].presence
        return error('mtasks_issue_id missing') unless issue_id

        parent = find_message
        return error('thread root message not found') unless parent

        project_link = parent.channel.mtasks_project_link
        return error('thread channel has no project link') unless project_link&.server_integration_id == @integration.id

        validation_error = validate_issue_against_project(issue_id, project_link)
        return validation_error if validation_error

        link = upsert_issue_link(parent, project_link, issue_id, @data['mtasks_issue_identifier'])
        Result.new(ok: true, link: link)
      end

      def validate_issue_against_project(issue_id, project_link)
        remote = Jait::Fetcher.call(integration: project_link.server_integration, kind: 'issue',
                                    team_id: project_link.mtasks_team_id, id: issue_id)
        return error('issue not found on mtasks') if remote.nil?
        return nil if remote['project_id'].to_i == project_link.mtasks_project_id.to_i

        issue_proj = remote['project_id']
        chan_proj = project_link.mtasks_project_id
        error("issue project mismatch (issue=#{issue_proj} channel=#{chan_proj})")
      end

      def remove_project_channel
        channel = find_channel
        return error('channel not found') unless channel

        project_id = @data['mtasks_project_id'].presence
        return error('mtasks_project_id missing') unless project_id

        link = integration_links.find_by(link_type: MtasksLink::PROJECT_CHANNEL,
                                         channel_id: channel.id,
                                         mtasks_project_id: project_id)
        link&.destroy!
        Result.new(ok: true)
      end

      def remove_issue_thread
        issue_id = @data['mtasks_issue_id'].presence
        return error('mtasks_issue_id missing') unless issue_id

        parent = find_message
        return error('thread root message not found') unless parent

        link = integration_links.find_by(link_type: MtasksLink::ISSUE_THREAD,
                                         thread_id: parent.id,
                                         mtasks_issue_id: issue_id)
        link&.destroy!
        Result.new(ok: true)
      end

      # ---- upserts ----

      def upsert_project_link(channel, project_id, team_id)
        link = MtasksLink.where(link_type: MtasksLink::PROJECT_CHANNEL,
                                channel_id: channel.id,
                                mtasks_project_id: project_id).first_or_initialize
        link.assign_attributes(
          server_integration: @integration,
          mtasks_team_id: team_id,
          created_by_user: resolve_creator(channel.server)
        )
        link.save!
        link
      end

      def upsert_issue_link(parent, project_link, issue_id, identifier)
        link = MtasksLink.where(link_type: MtasksLink::ISSUE_THREAD,
                                thread_id: parent.id,
                                mtasks_issue_id: issue_id).first_or_initialize
        link.assign_attributes(
          server_integration: project_link.server_integration,
          mtasks_team_id: project_link.mtasks_team_id,
          mtasks_issue_identifier: identifier,
          created_by_user: resolve_creator(parent.channel.server)
        )
        link.save!
        link
      end

      # ---- helpers ----

      def find_channel
        @integration.server.channels.find_by(id: @data['hourglass_channel_id'])
      end

      def find_message
        Message.joins(:channel)
               .where(channels: { server_id: @integration.server_id })
               .find_by(id: @data['hourglass_thread_id'])
      end

      def integration_links
        MtasksLink.where(server_integration: @integration)
      end

      # Resolve the mtasks team for an inbound link.created event. The payload's
      # mtasks_team_id (already verified against this integration) wins; when
      # absent, probe this integration's teams, refreshing them once if the
      # project isn't found.
      def resolve_with_refresh(project_id:)
        return @data['mtasks_team_id'].to_i if @data['mtasks_team_id'].present?

        team_id = resolve_team_id(project_id: project_id)
        return team_id if team_id
        return nil unless @integration.refresh_discovered_teams!

        resolve_team_id(project_id: project_id)
      end

      # Probe each discovered team for the project. Verifies even single-team
      # integrations — a "lone" team is no guarantee the project actually
      # lives there, and assigning the wrong mtasks_team_id leaves the link
      # unrecoverably broken.
      def resolve_team_id(project_id:)
        Array(@integration.discovered_teams).each do |t|
          remote = Jait::Fetcher.call(integration: @integration, kind: 'project', team_id: t['id'], id: project_id)
          return t['id'] if remote
        end
        nil
      end

      def resolve_creator(server)
        if (mtasks_user_id = @data['created_by_user_id'])
          mapped = MtasksUserMap.find_by(mtasks_user_id: mtasks_user_id)
          return mapped.hourglass_user if mapped
        end
        server.owner
      end

      def integration_usable?
        @integration.present? && @integration.enabled? && @integration.jait?
      end

      def foreign_team_error(team_id)
        error("team #{team_id} not in integration #{@integration.id}")
      end

      def error(message)
        Result.new(ok: false, error: message)
      end
    end
  end
end
