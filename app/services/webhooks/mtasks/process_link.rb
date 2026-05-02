module Webhooks
  module Mtasks
    class ProcessLink < Service
      Result = Struct.new(:ok, :link, :error, keyword_init: true)

      def initialize(delivery:)
        @delivery = delivery
        @event = delivery.event_type
        @data = delivery.payload['data'] || {}
      end

      def call
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

      def create_project_channel
        channel = find_channel
        return error('channel not found') unless channel

        integration = integration_for(channel)
        return error('no enabled integration') unless integration

        project_id = @data['mtasks_project_id'].presence
        return error('mtasks_project_id missing') unless project_id

        team_id = resolve_team_id(integration, project_id: project_id)
        return error('team not resolvable') unless team_id

        link = upsert_project_link(channel, integration, project_id, team_id)
        broadcast_channel_header(channel)
        Result.new(ok: true, link: link)
      end

      def create_issue_thread
        issue_id = @data['mtasks_issue_id'].presence
        return error('mtasks_issue_id missing') unless issue_id

        parent = find_message
        return error('thread root message not found') unless parent

        project_link = parent.channel.mtasks_project_link
        return error('thread channel has no project link') unless project_link

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

        link = MtasksLink.find_by(link_type: MtasksLink::PROJECT_CHANNEL,
                                  channel_id: channel.id,
                                  mtasks_project_id: project_id)
        link&.destroy!
        broadcast_channel_header(channel)
        Result.new(ok: true)
      end

      def remove_issue_thread
        issue_id = @data['mtasks_issue_id'].presence
        return error('mtasks_issue_id missing') unless issue_id

        parent = find_message
        return error('thread root message not found') unless parent

        link = MtasksLink.find_by(link_type: MtasksLink::ISSUE_THREAD,
                                  thread_id: parent.id,
                                  mtasks_issue_id: issue_id)
        link&.destroy!
        Result.new(ok: true)
      end

      # ---- upserts ----

      def upsert_project_link(channel, integration, project_id, team_id)
        link = MtasksLink.where(link_type: MtasksLink::PROJECT_CHANNEL,
                                channel_id: channel.id,
                                mtasks_project_id: project_id).first_or_initialize
        link.assign_attributes(
          server_integration: integration,
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
        Channel.find_by(id: @data['hourglass_channel_id'])
      end

      def find_message
        Message.find_by(id: @data['hourglass_thread_id'])
      end

      def integration_for(channel)
        channel.server.server_integrations.enabled.for_kind(ServerIntegration::KIND_JAIT).first
      end

      def resolve_team_id(integration, project_id:)
        teams = Array(integration.discovered_teams)
        return teams.first['id'] if teams.size == 1

        teams.each do |t|
          remote = Jait::Fetcher.call(integration: integration, kind: 'project', team_id: t['id'], id: project_id)
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

      def broadcast_channel_header(channel)
        Turbo::StreamsChannel.broadcast_replace_to(
          channel,
          target: "channel_#{channel.id}_jait_linked_badge",
          partial: 'channels/jait_linked_badge',
          locals: { channel: channel }
        )
      end

      def error(message)
        Result.new(ok: false, error: message)
      end
    end
  end
end
