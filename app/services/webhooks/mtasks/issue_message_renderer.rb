module Webhooks
  module Mtasks
    class IssueMessageRenderer < Service
      FALLBACK_ACTOR = 'an mtasks user'.freeze

      def initialize(event_type:, data:, actor_username: nil)
        @event_type = event_type
        @data = data || {}
        @actor_username = actor_username.presence
      end

      def call
        case @event_type
        when 'issue.created'        then render_created
        when 'issue.status_changed' then render_status_changed
        when 'issue.assigned'       then render_assigned
        end
      end

      private

      def render_created
        title = @data['title'].to_s.strip
        title_part = title.empty? ? '' : " '#{title}'"
        "// issue created · #{ident}#{title_part}#{by}"
      end

      def render_status_changed
        from = @data['from_lane_name'].to_s.strip
        to = @data['to_lane_name'].to_s.strip
        "// status · #{ident} #{from} → #{to}#{by}"
      end

      def render_assigned
        email = @data['assignee_email'].to_s
        handle = email.split('@').first.presence || "user##{@data['assignee_user_id']}"
        "// assigned · #{ident} → @#{handle}#{by}"
      end

      def ident
        @data['identifier'].to_s.presence || "issue##{@data['issue_id']}"
      end

      def by
        " by @#{@actor_username || FALLBACK_ACTOR}"
      end
    end
  end
end
