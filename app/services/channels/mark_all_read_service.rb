class Channels::MarkAllReadService < Service
  def initialize(user:)
    @user = user
  end

  def call
    now = Time.current

    @user.servers.each do |server|
      channel_ids = server.channels
                          .visible_to(@user)
                          .where.not(last_message_at: nil)
                          .pluck(:id)

      next if channel_ids.empty?

      # Upsert memberships so channels never visited also get marked read
      channel_ids.each do |ch_id|
        ChannelMembership.find_or_create_by!(user: @user, channel_id: ch_id)
      end

      ChannelMembership.where(user: @user, channel_id: channel_ids)
                       .update_all(last_read_at: now)

      broadcast_cleared_indicators(server, channel_ids)
    end

    broadcast_title_cleared
  end

  private

  def broadcast_cleared_indicators(_server, channel_ids)
    classes = 'flex-shrink-0 ml-auto flex items-center'

    channel_ids.each do |ch_id|
      target_id = "unread_indicator_channel_#{ch_id}"
      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{@user.id}_unread",
        target: target_id,
        html: "<span id=\"#{target_id}\" class=\"#{classes}\"></span>"
      )
    end
  end

  def broadcast_title_cleared
    html = '<span id="unread_title_indicator" class="hidden"></span>'

    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{@user.id}_unread_title",
      target: 'unread_title_indicator',
      html: html
    )
  end
end
