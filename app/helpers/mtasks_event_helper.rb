module MtasksEventHelper
  def mtasks_actor_user(data)
    email = data['actor_email'].to_s.strip
    return nil if email.blank?

    User.find_by(email_address: email.downcase)
  end

  def mtasks_open_in_jait_url(data)
    data['source_url'].to_s.strip.presence
  end

  def mtasks_view_source(data)
    return nil unless data['event_type'].to_s.start_with?('issue.')

    issue_id = data['issue_id']
    return nil if issue_id.blank?

    link = MtasksLink.issue_threads.find_by(mtasks_issue_id: issue_id)
    return nil unless link&.thread

    {
      label: 'view issue',
      path: server_channel_message_thread_path(link.thread.channel.server, link.thread.channel, link.thread)
    }
  end

  def mtasks_event_partial(event_type)
    "messages/mtasks_event/#{event_type.to_s.tr('.', '_')}"
  end
end
