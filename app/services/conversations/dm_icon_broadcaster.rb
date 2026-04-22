class Conversations::DmIconBroadcaster
  TARGETS = %w[dm_unread_badge dm_unread_badge_mobile].freeze
  DOT_CLASSES = 'absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full bg-granny-smith-apple-600'.freeze

  def self.broadcast(user_id:, has_unread:)
    TARGETS.each do |target|
      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user_id}_unread_title",
        target: target,
        html: html_for(target, has_unread)
      )
    end
  end

  def self.html_for(target, has_unread)
    dot = has_unread ? %(<span class="#{DOT_CLASSES}"></span>) : ''
    %(<span id="#{target}">#{dot}</span>)
  end
end
