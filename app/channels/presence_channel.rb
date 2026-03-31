class PresenceChannel < ApplicationCable::Channel
  @online = Hash.new { |h, k| h[k] = Set.new }
  @mutex = Mutex.new

  class << self
    attr_reader :online, :mutex

    def online_count(server_id)
      mutex.synchronize { online[server_id]&.size || 0 }
    end
  end

  def subscribed
    @server_id = params[:server_id].to_i
    server = Server.find_by(id: @server_id)
    reject unless server

    self.class.mutex.synchronize { self.class.online[@server_id].add(current_user.id) }
    stream_from "presence:server:#{@server_id}"
    broadcast_presence
  end

  def unsubscribed
    return unless @server_id

    self.class.mutex.synchronize { self.class.online[@server_id].delete(current_user.id) }
    broadcast_presence
  end

  private

  def broadcast_presence
    count = self.class.online_count(@server_id)
    dots = (1..[count, 3].min).map { '<span class="w-1.5 h-1.5 rounded-full bg-granny-smith-apple-300"></span>' }.join

    html = <<~HTML
      <span id="server_#{@server_id}_presence" class="flex items-center gap-1">
        <span class="flex gap-0.5">#{dots}</span>
        #{count} online
      </span>
    HTML

    Turbo::StreamsChannel.broadcast_replace_to(
      "server_#{@server_id}_presence",
      target: "server_#{@server_id}_presence",
      html: html
    )
  end
end
