module Messages
  module SlashCommands
    class IssueHandler < Service
      Result = Struct.new(:ok, :message, :error, keyword_init: true)

      def initialize(channel:, user:, args:, raw_body: nil)
        @channel = channel
        @user = user
        @args = args.to_s.strip
        @raw_body = raw_body
      end

      def call
        return post_system('Usage: /issue [title]') if @args.blank?

        link = @channel.mtasks_project_link
        if link.nil?
          return post_system("This channel isn't linked to an mtasks project. Use /link to connect one first.")
        end

        integration = @channel.server.jait_integration
        if integration.nil? || !integration.configured?
          return post_system('mtasks integration is not configured for this server.')
        end

        issue = create_issue(integration, link)
        return @failure_result if @failure_result

        message = create_card_message(integration, link, issue)
        create_link(integration, link, issue, message)
        Messages::PostCreateBroadcaster.call(channel: @channel, user: @user, message: message)
        Result.new(ok: true, message: message)
      end

      private

      def create_issue(integration, link)
        integration.client.create_issue(
          team_id: link.mtasks_team_id,
          project_id: link.mtasks_project_id,
          title: @args,
          creator: @user.email_address
        )
      rescue Jait::ApiClient::Error => e
        @failure_result = post_system("Failed to create issue: #{e.message}")
        nil
      end

      def create_card_message(integration, link, issue)
        @channel.messages.create!(
          user: @user,
          message_type: :regular,
          body: issue['title'].to_s,
          parent_message_id: nil,
          data: {
            'source' => 'mtasks',
            'kind' => 'issue_card',
            'issue' => issue,
            'team_id' => link.mtasks_team_id,
            'integration_id' => integration.id
          }
        )
      end

      def create_link(integration, link, issue, message)
        MtasksLink.create!(
          link_type: MtasksLink::ISSUE_THREAD,
          server_integration: integration,
          thread: message,
          mtasks_issue_id: issue['id'],
          mtasks_team_id: link.mtasks_team_id,
          created_by_user: @user
        )
      end

      def post_system(text)
        message = @channel.messages.create!(
          user: @user,
          message_type: :system,
          body: text,
          parent_message_id: nil,
          data: { 'source' => 'mtasks', 'kind' => 'slash_command' }
        )
        Messages::PostCreateBroadcaster.call(channel: @channel, user: @user, message: message)
        Result.new(ok: false, message: message, error: text)
      end
    end
  end
end
