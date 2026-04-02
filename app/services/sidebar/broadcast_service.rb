class Sidebar::BroadcastService < Service
  def initialize(server:, action:, category: nil)
    @server = server
    @action = action
    @category = category
  end

  def call
    case @action
    when :replace_category
      broadcast_replace_category
    when :replace_all_categories
      broadcast_replace_all_categories
    end
  end

  private

  def broadcast_replace_category
    %w[desktop mobile].each do |prefix|
      Turbo::StreamsChannel.broadcast_replace_to(
        "server_#{@server.id}_sidebar",
        target: "#{prefix}_category_#{@category.id}",
        partial: 'servers/channel_sidebar_category',
        locals: { category: @category, server: @server, current_channel: nil, mobile: prefix == 'mobile',
                  unread_channel_ids: [] }
      )
    end
  end

  def broadcast_replace_all_categories
    categories = @server.categories.ordered.to_a

    %w[desktop mobile].each do |prefix|
      html = categories.map do |category|
        ApplicationController.render(
          partial: 'servers/channel_sidebar_category',
          locals: { category: category, server: @server, current_channel: nil, mobile: prefix == 'mobile',
                    unread_channel_ids: [] }
        )
      end.join

      target_id = "#{prefix}_categories_server_#{@server.id}"
      css = "flex-1 overflow-y-auto #{'py-2' if prefix == 'desktop'}"
      data_attr = prefix == 'desktop' ? ' data-controller="sidebar-active"' : ''
      wrapper = "<div id=\"#{target_id}\" class=\"#{css}\"#{data_attr}>#{html}</div>"

      Turbo::StreamsChannel.broadcast_replace_to(
        "server_#{@server.id}_sidebar",
        target: target_id,
        html: wrapper
      )
    end
  end
end
