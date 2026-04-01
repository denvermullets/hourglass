class Messages::UpdateService < Service
  def initialize(message:, params:)
    @message = message
    @params = params
  end

  def call
    purge_removed_files
    update_message
    broadcast_update

    @message
  end

  private

  def purge_removed_files
    purge_file_ids = @params.delete(:purge_file_ids)
    @message.files.where(id: purge_file_ids).each(&:purge_later) if purge_file_ids.present?
  end

  def update_message
    sanitized_params = @params.merge(
      body: Messages::SanitizeService.call(html: @params[:body])
    )

    @message.update!(sanitized_params.merge(edited_at: Time.current))
    @message.files.load if @message.files.attached?
  end

  def broadcast_update
    if @message.parent_message_id.present?
      Turbo::StreamsChannel.broadcast_replace_to(
        "thread_#{@message.parent_message_id}",
        target: @message,
        partial: 'threads/reply',
        locals: { reply: @message, server: @message.channel.server, channel: @message.channel }
      )
    else
      Turbo::StreamsChannel.broadcast_replace_to(
        @message.channel,
        target: @message,
        partial: 'messages/message',
        locals: { message: @message }
      )
    end
  end
end
