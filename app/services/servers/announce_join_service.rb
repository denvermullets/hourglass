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

    @channel.update_column(:last_message_at, message.created_at)
    message
  end
end
