module MtasksEventHelper
  def mtasks_actor_user(data)
    email = data['actor_email'].to_s.strip
    return nil if email.blank?

    User.find_by(email_address: email.downcase)
  end

  def mtasks_open_in_jait_url(message, data)
    integration = message.channel&.server&.jait_integration
    base = integration&.base_url.to_s.strip
    team_slug = data['team_slug'].to_s.strip
    identifier = data['identifier'].to_s.strip
    return nil if base.blank? || team_slug.blank? || identifier.blank?

    "#{base.chomp('/')}/teams/#{team_slug}/issues/#{identifier}"
  end

  def mtasks_view_issue_path(data)
    issue_id = data['issue_id']
    return nil if issue_id.blank?

    link = MtasksLink.issue_threads.find_by(mtasks_issue_id: issue_id)
    return nil unless link&.thread

    server_channel_message_thread_path(link.thread.channel.server, link.thread.channel, link.thread)
  end

  def mtasks_event_partial(event_type)
    "messages/mtasks_event/#{event_type.to_s.tr('.', '_')}"
  end
end
