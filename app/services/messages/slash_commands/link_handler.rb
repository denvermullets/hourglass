module Messages
  module SlashCommands
    class LinkHandler < Service
      Result = Struct.new(:ok, :message, :error, keyword_init: true)

      def initialize(channel:, user:, args:, raw_body: nil, parent_message_id: nil)
        @channel = channel
        @user = user
        @args = args.to_s.strip
        @raw_body = raw_body
        @parent_message_id = parent_message_id
      end

      def call
        return post_system('Usage: /link [JAIT-id]') if @args.blank?

        ctx = resolve_context
        return ctx if ctx.is_a?(Result)

        link_to_existing_issue(ctx)
      end

      private

      def resolve_context
        parent = parent_message
        return post_system('/link can only be used inside a thread.') if parent.nil?

        project_link = @channel.mtasks_project_link
        return post_system("This channel isn't linked to an mtasks project.") if project_link.nil?

        integration = @channel.server.jait_integration
        if integration.nil? || !integration.configured?
          return post_system('mtasks integration is not configured for this server.')
        end

        if MtasksLink.issue_threads.exists?(thread_id: parent.id)
          return post_system('This thread is already linked to an issue.')
        end

        { parent: parent, project_link: project_link, integration: integration }
      end

      def link_to_existing_issue(ctx)
        issue = fetch_issue(ctx[:integration], ctx[:project_link])
        return @failure_result if @failure_result
        return post_system("Issue #{@args} not found.") if issue.nil?

        message = create_card_message(ctx[:integration], ctx[:project_link], issue, ctx[:parent])
        create_link(ctx[:integration], ctx[:project_link], issue, ctx[:parent])
        Messages::PostCreateBroadcaster.call(channel: @channel, user: @user, message: message)
        emit_link_created(ctx[:integration], ctx[:project_link], issue, ctx[:parent])
        Result.new(ok: true, message: message)
      end

      def parent_message
        return nil if @parent_message_id.blank?

        @channel.messages.find_by(id: @parent_message_id)
      end

      def fetch_issue(integration, project_link)
        integration.client.fetch_issue_by_identifier(project_link.mtasks_team_id, @args)
      rescue Jait::ApiClient::Error => e
        @failure_result = post_system("Failed to look up issue: #{e.message}")
        nil
      end

      def create_card_message(integration, project_link, issue, parent)
        @channel.messages.create!(
          user: @user,
          message_type: :regular,
          body: issue['title'].to_s,
          parent_message_id: parent.id,
          data: {
            'source' => 'mtasks',
            'kind' => 'issue_card',
            'issue' => issue,
            'team_id' => project_link.mtasks_team_id,
            'integration_id' => integration.id
          }
        )
      end

      def create_link(integration, project_link, issue, parent)
        MtasksLink.create!(
          link_type: MtasksLink::ISSUE_THREAD,
          server_integration: integration,
          thread: parent,
          mtasks_issue_id: issue['id'],
          mtasks_issue_identifier: issue['identifier'],
          mtasks_team_id: project_link.mtasks_team_id,
          created_by_user: @user
        )
      end

      def emit_link_created(integration, project_link, issue, parent)
        MtasksOutboundEmitterJob.perform_later(
          integration_id: integration.id,
          event_type: 'link.created',
          data: {
            link_type: 'issue_thread',
            mtasks_issue_id: issue['id'],
            mtasks_team_id: project_link.mtasks_team_id,
            hourglass_thread_id: parent.id,
            created_by_user_id: @user.id
          }
        )
      end

      def post_system(text)
        message = @channel.messages.create!(
          user: @user,
          message_type: :system,
          body: text,
          parent_message_id: @parent_message_id,
          data: { 'source' => 'mtasks', 'kind' => 'slash_command' }
        )
        Messages::PostCreateBroadcaster.call(channel: @channel, user: @user, message: message)
        Result.new(ok: false, message: message, error: text)
      end
    end
  end
end
