class Mentions::DetectService < Service
  def initialize(message:)
    @message = message
  end

  def call
    return if @message.body.blank?
    return if @message.channel.blank? && @message.conversation.blank?

    usernames = extract_usernames
    return if usernames.empty?

    mentioned_users = resolve_mentioned_users(usernames)
    persist_cross_app_mentions(mentioned_users)

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

  def extract_usernames
    @message.body.scan(/@(\w{3,20})/).flatten.to_set(&:downcase)
  end

  # A mentioned user who is also linked to Jait (has an MtasksUserMap) is emitted as a
  # cross-app mention; the same user still receives a local notification above.
  def persist_cross_app_mentions(mentioned_users)
    return if mentioned_users.empty?

    users_by_id = mentioned_users.index_by(&:id)
    external = MtasksUserMap.where(hourglass_user_id: users_by_id.keys).map do |map|
      {
        'mtasks_user_id' => map.mtasks_user_id,
        'email' => map.email,
        'display_name' => users_by_id[map.hourglass_user_id]&.username
      }
    end
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
