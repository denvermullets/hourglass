class Notifications::StreamBuilder
  class << self
    def badge_streams(count)
      badge = badge_html(count)
      mobile = mobile_badge_html(count)

      turbo_replace('notification_badge', badge) +
        turbo_replace('notification_badge_mobile', mobile)
    end

    def notification_stream(notification)
      item = notification_html(notification)
      turbo_prepend('notification_list', item)
    end

    private

    def turbo_replace(target, content)
      <<~HTML
        <turbo-stream action="replace" target="#{target}">
          <template>#{content}</template>
        </turbo-stream>
      HTML
    end

    def turbo_prepend(target, content)
      <<~HTML
        <turbo-stream action="prepend" target="#{target}">
          <template>#{content}</template>
        </turbo-stream>
      HTML
    end

    def badge_html(count)
      return '<span id="notification_badge"></span>' unless count.positive?

      display = count > 99 ? '99+' : count.to_s
      badge_classes = [
        'absolute -top-1 -right-1',
        'bg-granny-smith-apple-600 text-bunker-950',
        'text-[7px] font-bold rounded-full',
        'min-w-[14px] h-[14px]',
        'flex items-center justify-center px-0.5'
      ].join(' ')

      %(<span id="notification_badge"><span class="#{badge_classes}">#{display}</span></span>)
    end

    def mobile_badge_html(count)
      return '<span id="notification_badge_mobile"></span>' unless count.positive?

      dot_classes = [
        'absolute -top-0.5 -right-0.5',
        'w-2 h-2 rounded-full',
        'bg-granny-smith-apple-600'
      ].join(' ')

      %(<span id="notification_badge_mobile"><span class="#{dot_classes}"></span></span>)
    end

    def notification_html(notification)
      data = notification.data || {}
      attrs = {
        id: notification.id,
        actor: ERB::Util.html_escape(notification.actor.username),
        body: notification_body(notification.notification_type, data),
        preview: preview_html(data),
        url: notification_url(data)
      }
      notification_template(attrs)
    end

    def notification_template(attrs)
      <<~HTML
        <div id="notification_#{attrs[:id]}" class="group">
          <a href="#{attrs[:url]}" data-notification-link data-notification-id="#{attrs[:id]}"
             class="flex items-start gap-2.5 px-3 py-2.5 no-underline transition-colors hover:bg-bunker-875">
            <div class="flex-shrink-0 mt-1.5">
              <div class="w-1.5 h-1.5 rounded-full bg-granny-smith-apple-500"></div>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[10px] text-bunker-300 leading-relaxed m-0">
                <span class="font-bold text-bunker-200">#{attrs[:actor]}</span> #{attrs[:body]}
              </p>
              #{attrs[:preview]}
              <time class="text-[8px] text-bunker-700 mt-0.5 block">just now</time>
            </div>
          </a>
        </div>
      HTML
    end

    def notification_body(type, data)
      channel = ERB::Util.html_escape(data['channel_name'])
      channel_span = %(<span class="text-jordy-blue-400">##{channel}</span>)

      case type
      when 'mention' then "mentioned you in #{channel_span}"
      when 'reply' then "replied to your thread in #{channel_span}"
      when 'reaction' then "reacted #{ERB::Util.html_escape(data['emoji'])} to your message"
      when 'dm' then 'sent you a message'
      when 'channel_invite' then "invited you to #{channel_span}"
      when 'system' then ERB::Util.html_escape(data['message'])
      end
    end

    def preview_html(data)
      return '' if data['preview'].blank?

      escaped = ERB::Util.html_escape(data['preview'])
      %(<p class="text-[9px] text-bunker-600 mt-0.5 truncate m-0">#{escaped}</p>)
    end

    def notification_url(data)
      helpers = Rails.application.routes.url_helpers
      if data['server_id'] && data['channel_id']
        path = helpers.server_channel_path(data['server_id'], data['channel_id'])
        data['message_id'] ? "#{path}#message_#{data['message_id']}" : path
      else
        helpers.notifications_path
      end
    end
  end
end
