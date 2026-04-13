class Servers::AnnounceJoinService < Service
  def initialize(server:, user:)
    @server = server
    @user = user
  end

  def call
    @channel = @server.channels.find_by(name: 'general')
    return unless @channel

    message = @channel.messages.create!(
      user: @user,
      message_type: :user_join,
      body: ''
    )

    broadcast_message(message)
    broadcast_unread_indicators(message)
    message
  end

  private

  def broadcast_message(message)
    fresh_message = Message.includes(user: { avatar_attachment: :blob }).find(message.id)

    broadcast_date_separator(message)

    Turbo::StreamsChannel.broadcast_append_to(
      @channel,
      target: 'messages',
      partial: 'messages/message',
      locals: { message: fresh_message, grouped: false, context: :channel }
    )
  end

  def broadcast_unread_indicators(message)
    @channel.update_column(:last_message_at, message.created_at)

    @server.memberships.where.not(user_id: @user.id).pluck(:user_id).each do |user_id|
      target_id = "unread_indicator_channel_#{@channel.id}"

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user_id}_unread",
        target: target_id,
        html: <<~HTML
          <span id="#{target_id}" class="flex-shrink-0 ml-auto flex items-center">
            <span class="w-1.5 h-1.5 rounded-full bg-granny-smith-apple-400 block"></span>
          </span>
        HTML
      )
    end
  end

  def broadcast_date_separator(message)
    previous = @channel.messages.not_deleted
                       .where('created_at < ?', message.created_at)
                       .order(created_at: :desc)
                       .pick(:created_at)

    return if previous&.to_date == message.created_at.to_date

    Turbo::StreamsChannel.broadcast_append_to(
      @channel,
      target: 'messages',
      partial: 'messages/date_separator',
      locals: { date: message.created_at }
    )
  end
end
