class Messages::UpdateService < Service
  include Messages::MtasksEmittable

  def initialize(message:, params:)
    @message = message
    @params = params
  end

  def call
    purge_removed_files
    update_message
    emit_outbound

    @message
  end

  private

  def emit_outbound
    return unless emittable?(@message)
    return if @message.data['mtasks_comment_id'].blank?

    enqueue_update(@message)
  end

  def purge_removed_files
    purge_file_ids = @params.delete(:purge_file_ids)
    @message.files.where(id: purge_file_ids).each(&:purge_later) if purge_file_ids.present?
  end

  def update_message
    attrs = @params.dup
    if attrs.key?(:body)
      attrs[:body] = attrs[:body].to_s.strip
      attrs[:data] = @message.data.merge('format' => 'markdown')
    end

    @message.update!(attrs.merge(edited_at: Time.current))
    @message.files.load if @message.files.attached?
  end
end
