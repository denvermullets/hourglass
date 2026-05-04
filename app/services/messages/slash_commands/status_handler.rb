module Messages
  module SlashCommands
    class StatusHandler < Service
      Result = Struct.new(:ok, :message, :error, keyword_init: true)

      def initialize(channel:, user:, args:, raw_body: nil, parent_message_id: nil)
        @channel = channel
        @user = user
        @args = args.to_s.strip
        @raw_body = raw_body
        @parent_message_id = parent_message_id
      end

      def call
        return post_system('Usage: /status [keyword]') if @args.blank?

        parent = parent_message
        return post_system('/status can only be used inside a thread.') if parent.nil?

        link = MtasksLink.issue_threads.find_by(thread_id: parent.id)
        return post_system("This thread isn't linked to an issue. Use /link first.") if link.nil?

        integration = link.server_integration
        if integration.nil? || !integration.configured?
          return post_system('mtasks integration is not configured for this server.')
        end

        update_status(integration, link)
        return @failure_result if @failure_result

        post_confirmation(link)
      end

      private

      def parent_message
        return nil if @parent_message_id.blank?

        @channel.messages.find_by(id: @parent_message_id)
      end

      def update_status(integration, link)
        integration.client.update_issue_status(
          team_id: link.mtasks_team_id,
          issue_id: link.mtasks_issue_id,
          status: @args.downcase
        )
      rescue Jait::ApiClient::Error => e
        @failure_result = post_system("Failed to update status: #{e.message}")
        nil
      end

      def post_confirmation(link)
        identifier = link.mtasks_issue_identifier.presence || "issue ##{link.mtasks_issue_id}"
        message = @channel.messages.create!(
          user: @user,
          message_type: :system,
          body: "Status set to #{@args.downcase} on #{identifier}.",
          parent_message_id: @parent_message_id,
          data: { 'source' => 'mtasks', 'kind' => 'slash_command' }
        )
        Messages::PostCreateBroadcaster.call(channel: @channel, user: @user, message: message)
        Result.new(ok: true, message: message)
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
