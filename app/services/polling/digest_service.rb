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
      [container_digest, thread_digest, unread_digest, notifications_digest]
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

    # Sidebar unread dots + read-state. The booleans flip when unread status changes;
    # max(last_read_at) moves when the user reads something (in another tab/device).
    def unread_digest
      [
        @user.unread_channels?,
        @user.unread_conversations?,
        stamp(ChannelMembership.where(user: @user).maximum(:last_read_at)),
        stamp(ConversationMembership.where(user: @user).maximum(:last_read_at))
      ].join(',')
    end

    def notifications_digest
      [stamp(@user.notifications.maximum(:updated_at)), @user.unread_notification_count].join(',')
    end

    def stamp(time)
      time ? time.to_f : '-'
    end
  end
end
