module Webhooks
  module Mtasks
    class ProcessIssue < Service # rubocop:disable Metrics/ClassLength
      Result = Struct.new(:ok, :message, :error, keyword_init: true)

      def initialize(delivery:)
        @delivery = delivery
        @event = delivery.event_type
        @data = delivery.payload['data'] || {}
      end

      def call
        case @event
        when 'issue.created'        then handle_created
        when 'issue.updated'        then handle_updated
        when 'issue.status_changed' then handle_status_changed
        when 'issue.assigned'       then handle_assigned
        else error("unhandled #{@event}")
        end
      end

      private

      # ---- per-event handlers ----

      def handle_created
        issue_id = @data['issue_id'].presence
        identifier = @data['identifier'].presence
        project_id = @data['project_id'].presence
        team_id = @data['team_id'].presence

        return error('issue.created missing required fields') unless issue_id && identifier && project_id

        upsert_cache_from_payload(issue_id: issue_id, identifier: identifier, payload: @data)
        post_message_if_destination_found(issue_id: issue_id, project_id: project_id, integration_team_id: team_id)
      end

      def handle_updated
        issue_id = @data['id'].presence || @data['issue_id'].presence
        identifier = @data['identifier'].presence
        return error('issue.updated missing id/identifier') unless issue_id && identifier

        upsert_cache_from_full_serializer(issue_id: issue_id, identifier: identifier, payload: @data)
        Result.new(ok: true)
      end

      def handle_status_changed
        process_event_with_cached_lookup do |cache|
          cache.lane_id = @data['to_lane_id'] if @data.key?('to_lane_id')
          cache.status_name = @data['to_lane_name'] if @data.key?('to_lane_name')
          cache.last_synced_at = Time.current
          cache.save!
        end
      end

      def handle_assigned
        process_event_with_cached_lookup do |cache|
          cache.assignee_email = @data['assignee_email'] if @data.key?('assignee_email')
          cache.last_synced_at = Time.current
          cache.save!
        end
      end

      # ---- shared status_changed/assigned flow ----

      def process_event_with_cached_lookup
        issue_id = @data['issue_id'].presence
        identifier = @data['identifier'].presence
        return error("#{@event} missing issue_id/identifier") unless issue_id && identifier

        cache = MtasksIssueCache.find_by(mtasks_issue_id: issue_id) || backfill_cache(issue_id, identifier)
        return error('issue not in cache and not found on mtasks') unless cache

        yield cache

        project_id = project_id_from_cache(cache)
        return error('cached issue has no project_id') unless project_id

        post_message_if_destination_found(issue_id: issue_id, project_id: project_id, integration_team_id: nil)
      end

      def backfill_cache(issue_id, identifier)
        # No team_id in the payload — walk the integrations on every server until one resolves.
        ServerIntegration.enabled.for_kind(ServerIntegration::KIND_JAIT).find_each do |integration|
          Array(integration.discovered_teams).each do |t|
            remote = Jait::Fetcher.call(integration: integration, kind: 'issue', team_id: t['id'], id: issue_id)
            next unless remote

            return upsert_cache_from_full_serializer(issue_id: issue_id, identifier: identifier, payload: remote)
          end
        end
        nil
      end

      # ---- cache upserts ----

      def upsert_cache_from_payload(issue_id:, identifier:, payload:)
        cache = MtasksIssueCache.find_or_initialize_by(mtasks_issue_id: issue_id)
        cache.assign_attributes(
          identifier: identifier,
          title: payload['title'],
          payload: payload,
          last_synced_at: Time.current
        )
        cache.save!
        cache
      end

      def upsert_cache_from_full_serializer(issue_id:, identifier:, payload:)
        cache = MtasksIssueCache.find_or_initialize_by(mtasks_issue_id: issue_id)
        cache.assign_attributes(
          identifier: identifier,
          title: payload['title'],
          status_name: payload.dig('lane', 'name'),
          lane_id: payload.dig('lane', 'id'),
          priority: payload['priority'],
          assignee_email: payload.dig('assignee', 'email'),
          labels: Array(payload['labels']),
          payload: payload,
          last_synced_at: Time.current
        )
        cache.save!
        cache
      end

      def project_id_from_cache(cache)
        (cache.payload['project_id'] || cache.payload.dig('project', 'id')).presence
      end

      # ---- destination + posting ----

      def post_message_if_destination_found(issue_id:, project_id:, integration_team_id:)
        channel, parent = destination_for(issue_id: issue_id, project_id: project_id)
        unless channel
          bust_caches_best_effort(
            issue_id: issue_id, identifier: @data['identifier'], integration_team_id: integration_team_id
          )
          return Result.new(ok: true) # no destination → noop, not an error
        end

        bust_caches_for_channel(channel: channel, issue_id: issue_id, identifier: @data['identifier'])

        return Result.new(ok: true) unless event_allowed?(channel)

        body = IssueMessageRenderer.call(
          event_type: @event, data: @data, actor_username: actor_username
        )
        return Result.new(ok: true) if body.blank?

        message = Messages::CreateSystemService.call(
          channel: channel,
          body: body,
          data: build_message_data(issue_id),
          parent_message: parent
        )
        Result.new(ok: true, message: message)
      end

      def destination_for(issue_id:, project_id:)
        thread_link = MtasksLink.issue_threads.find_by(mtasks_issue_id: issue_id)
        return [thread_link.thread.channel, thread_link.thread] if thread_link&.thread

        project_link = MtasksLink.project_channels.find_by(mtasks_project_id: project_id)
        return [project_link.channel, nil] if project_link

        [nil, nil]
      end

      def event_allowed?(channel)
        case channel.mtasks_system_messages_pref
        when 'off' then false
        when 'status_only' then @event == 'issue.status_changed'
        else true
        end
      end

      def actor_username
        actor_id = @data['actor_user_id'] || @data['creator_user_id']
        return nil unless actor_id

        MtasksUserMap.find_by(mtasks_user_id: actor_id)&.hourglass_user&.username
      end

      def build_message_data(issue_id)
        {
          'source' => 'mtasks',
          'event_type' => @event,
          'mtasks_issue_id' => issue_id,
          'mtasks_issue_identifier' => @data['identifier'],
          'actor_user_id' => @data['actor_user_id'] || @data['creator_user_id']
        }.compact
      end

      # ---- cache busting ----

      def bust_caches_for_channel(channel:, issue_id:, identifier:)
        link = channel.mtasks_project_link
        return unless link

        bust_keys(
          integration: link.server_integration, team_id: link.mtasks_team_id,
          issue_id: issue_id, identifier: identifier
        )
      end

      def bust_caches_best_effort(issue_id:, identifier:, integration_team_id:)
        ServerIntegration.enabled.for_kind(ServerIntegration::KIND_JAIT).find_each do |integration|
          team_id = integration_team_id || Array(integration.discovered_teams).first&.dig('id')
          next unless team_id

          bust_keys(integration: integration, team_id: team_id, issue_id: issue_id, identifier: identifier)
        end
      end

      def bust_keys(integration:, team_id:, issue_id:, identifier:)
        Rails.cache.delete("jait:#{integration.id}:t#{team_id}:issue:#{issue_id}")
        Rails.cache.delete("jait:#{integration.id}:t#{team_id}:issue:ident:#{identifier}") if identifier.present?
      end

      def error(message)
        Result.new(ok: false, error: message)
      end
    end
  end
end
