module Api
  module V1
    class MessagesController < BaseController
      include Api::V1::Idempotency

      before_action :load_channel,        only: %i[index create]
      before_action :load_parent_message, only: %i[replies create_reply]

      def index
        scope = @channel.messages.root_messages.not_deleted.includes(:user)
        messages = paginate(scope)
        render json: messages.map { |m| MessageSerializer.new(m).as_json }
      end

      def create
        message = if mtasks_sourced?
                    Messages::CreateSystemService.call(
                      channel: @channel,
                      body: message_params[:body],
                      data: system_data,
                      attributed_user: current_user
                    )
                  else
                    Messages::CreateService.call(
                      channel: @channel,
                      user: current_user,
                      params: message_params
                    )
                  end
        render json: MessageSerializer.new(message).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      def replies
        scope = @parent.replies.not_deleted.includes(:user)
        replies = paginate(scope)
        render json: replies.map { |m| MessageSerializer.new(m).as_json }
      end

      def create_reply
        message = if mtasks_sourced?
                    Messages::CreateSystemService.call(
                      channel: @parent.channel,
                      body: message_params[:body],
                      data: system_data,
                      parent_message: @parent,
                      attributed_user: current_user
                    )
                  else
                    Messages::CreateService.call(
                      channel: @parent.channel,
                      user: current_user,
                      params: message_params.merge(parent_message_id: @parent.id)
                    )
                  end
        render json: MessageSerializer.new(message).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e.record)
      end

      private

      def load_channel
        @channel = Channel.visible_to(current_user).find_by(id: params[:channel_id] || params[:id])
        return if @channel

        render json: { error: 'Not Found', message: 'Channel not found' }, status: :not_found
      end

      def load_parent_message
        @parent = Message.not_deleted.find_by(id: params[:id])
        return render_message_not_found unless @parent

        render_message_not_found unless Channel.visible_to(current_user).exists?(id: @parent.channel_id)
      end

      def render_message_not_found
        render json: { error: 'Not Found', message: 'Message not found' }, status: :not_found
      end

      def message_params
        params.permit(
          :body,
          data: [
            :source, :event_type,
            :actor_email, :actor_name, :actor_username,
            :issue_id, :identifier, :title, :source_url,
            :team_slug, :project_id, :project_name,
            :priority, :status_lane_name,
            :assignee_email, :assignee_name, :assignee_username,
            :comment_id, :comment_body,
            :from_lane_name, :to_lane_name,
            :branch_name, :branch_url,
            { labels: %i[name color] }
          ]
        )
      end

      def mtasks_sourced?
        message_params.dig(:data, :source) == 'mtasks'
      end

      def system_data
        message_params[:data].to_h
      end
    end
  end
end
