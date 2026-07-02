# Builds a short, stable content digest for the polling-based refresh (Phase 2 of the
# WebSocket -> polling migration). The poller compares this digest against the value in
# <meta name="poll-digest"> and triggers a Turbo morph refresh only when it changes.
#
# The same service feeds both the layout meta tag and PollController#show, so the two
# digests are identical for identical state. Presence is intentionally omitted this phase
# (deferred to Phase 4 / HOUR-72).
module Polling
  class DigestService < Service
    def initialize(user:, channel: nil, conversation: nil, thread: nil)
      @user = user
      @channel = channel
      @conversation = conversation
      @thread = thread
    end

    def call
      Digest::MD5.hexdigest(parts.join('|'))
    end

    private

    def parts
      [container_digest, thread_digest, unread_digest, sidebar_digest, channel_link_digest, presence_digest,
       notifications_digest]
    end

    # Latest activity in the open channel/conversation. updated_at (not last_message_at)
    # so edits, soft-deletes and pins — which bump updated_at only — still register.
    def container_digest
      messageable = @channel || @conversation
      return '-' unless messageable

      stamp(messageable.messages.maximum(:updated_at))
    end

    # Thread parent + replies. replies_count catches new/removed replies even when
    # updated_at happens to collide.
    def thread_digest
      return '-' unless @thread

      [stamp(@thread.updated_at), stamp(@thread.replies.maximum(:updated_at)), @thread.replies_count].join(',')
    end

    # Sidebar unread dots + tab-title dot. Since broadcasts are gone (Phase 3), morph is the
    # only mechanism keeping these fresh, so the digest must move whenever ANY visible
    # channel/conversation gets a message (global last_message_at) or the user reads
    # something (max last_read_at, incl. reads on another tab/device). Booleans alone would
    # miss a second channel going unread while others already are.
    def unread_digest
      [
        stamp(visible_channels_last_activity),
        stamp(Conversation.for_user(@user).maximum(:last_message_at)),
        stamp(ChannelMembership.where(user: @user).maximum(:last_read_at)),
        stamp(ConversationMembership.where(user: @user).maximum(:last_read_at))
      ].join(',')
    end

    # Mirrors User#unread_channels? scoping so the digest reflects activity in any channel
    # the user can see across their servers.
    def visible_channels_last_activity
      Channel.visible_to(@user)
             .joins(:server)
             .where(servers: { id: @user.servers.select(:id) })
             .maximum(:last_message_at)
    end

    # Sidebar structure (channel/category create, archive, rename, reorder). last_message_at
    # bumps use update_column so they don't touch updated_at — this term only moves on
    # structural edits, keeping other users' sidebars fresh via morph now that the sidebar
    # broadcasts are gone.
    def sidebar_digest
      server_ids = @user.servers.select(:id)
      [
        stamp(Channel.where(server_id: server_ids).maximum(:updated_at)),
        stamp(Category.where(server_id: server_ids).maximum(:updated_at))
      ].join(',')
    end

    # jait link badge/panel are DB-derived; move the digest when a channel's link changes.
    def channel_link_digest
      return '-' unless @channel

      stamp(MtasksLink.where(channel_id: @channel.id).maximum(:updated_at))
    end

    # DB-backed presence ("N online"): morph the pill when a member crosses the 45s window.
    # Only channel pages show the pill; the count is stable between polls for active users.
    def presence_digest
      return '-' unless @channel

      @channel.server.online_count
    end

    def notifications_digest
      [stamp(@user.notifications.maximum(:updated_at)), @user.unread_notification_count].join(',')
    end

    def stamp(time)
      time ? time.to_f : '-'
    end
  end
end
