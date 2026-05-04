module Messages
  module SlashCommands
    class UnlinkHandler < Service
      Result = Struct.new(:ok, :message, :error, keyword_init: true)

      def initialize(channel:, user:, args:, raw_body: nil, parent_message_id: nil)
        @channel = channel
        @user = user
        @args = args.to_s.strip
        @raw_body = raw_body
        @parent_message_id = parent_message_id
      end

      def call
        parent = parent_message
        return post_system('/unlink can only be used inside a thread.') if parent.nil?

        link = MtasksLink.issue_threads.find_by(thread_id: parent.id)
        return post_system("This thread isn't linked to an issue.") if link.nil?

        emit_data = {
          link_type: 'issue_thread',
          mtasks_issue_id: link.mtasks_issue_id,
          mtasks_team_id: link.mtasks_team_id,
          hourglass_thread_id: parent.id
        }
        integration_id = link.server_integration_id
        identifier = link.mtasks_issue_identifier.presence || "issue ##{link.mtasks_issue_id}"
        link.destroy!

        MtasksOutboundEmitterJob.perform_later(
          integration_id: integration_id,
          event_type: 'link.removed',
          data: emit_data
        )

        post_confirmation("Unlinked from #{identifier}.")
      end

      private

      def parent_message
        return nil if @parent_message_id.blank?

        @channel.messages.find_by(id: @parent_message_id)
      end

      def post_confirmation(text)
        message = @channel.messages.create!(
          user: @user,
          message_type: :system,
          body: text,
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
