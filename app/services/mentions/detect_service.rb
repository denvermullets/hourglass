class Mentions::DetectService < Service
  def initialize(message:)
    @message = message
  end

  def call
    return if @message.body.blank?
    return if @message.channel.blank? && @message.conversation.blank?

    parsed = parse_body
    persist_cross_app_mentions(parsed[:external])

    usernames = parsed[:usernames]
    return if usernames.empty?

    mentioned_users = resolve_mentioned_users(usernames)

    mentioned_users.each do |user|
      Notifications::CreateService.call(
        user: user,
        actor: @message.user,
        notification_type: :mention,
        notifiable: @message,
        data: notification_data
      )
    end
  end

  private

  def parse_body
    usernames = Set.new
    external = []
    seen_mtasks_ids = Set.new

    Nokogiri::HTML5.fragment(@message.body).css('span.editor-mention').each do |span|
      classify_mention(span, usernames, external, seen_mtasks_ids)
    end

    plain_text = ActionController::Base.helpers.strip_tags(@message.body)
    plain_text.scan(/@(\w{3,20})/).flatten.each { |u| usernames << u }

    { usernames: usernames, external: external }
  end

  def classify_mention(span, usernames, external, seen_mtasks_ids)
    username = span['data-mention-username'].to_s
    return if username.blank?

    if span['data-external'] == 'true'
      mtasks_user_id = span['data-mtasks-user-id'].to_s
      return if mtasks_user_id.blank? || seen_mtasks_ids.include?(mtasks_user_id)

      seen_mtasks_ids << mtasks_user_id
      external << {
        'mtasks_user_id' => mtasks_user_id.to_i,
        'email' => username,
        'display_name' => username
      }
    else
      usernames << username
    end
  end

  def persist_cross_app_mentions(external)
    return if external.empty?

    @message.update_column(:data, @message.data.merge('cross_app_mentions' => external))
  end

  def resolve_mentioned_users(usernames)
    scope = if @message.conversation.present?
              @message.conversation.members
            else
              @message.channel.server.users
            end

    scope.where('LOWER(username) IN (?)', usernames.map(&:downcase))
         .where.not(id: @message.user_id)
  end

  def notification_data
    data = @message.in_conversation? ? conversation_notification_data : channel_notification_data
    data['parent_message_id'] = @message.parent_message_id if @message.parent_message_id
    data
  end

  def conversation_notification_data
    preview = ActionController::Base.helpers.strip_tags(@message.body).to_s.truncate(100)
    { 'conversation_id' => @message.conversation_id,
      'conversation_name' => @message.conversation.display_name(@message.user),
      'message_id' => @message.id, 'preview' => preview }
  end

  def channel_notification_data
    preview = ActionController::Base.helpers.strip_tags(@message.body).to_s.truncate(100)
    { 'channel_name' => @message.channel.name, 'server_name' => @message.channel.server.name,
      'server_id' => @message.channel.server_id, 'channel_id' => @message.channel_id,
      'message_id' => @message.id, 'preview' => preview }
  end
end
