class ConnectionMonitorChannel < ApplicationCable::Channel
  def subscribed
    stream_from "connection_monitor:#{current_user.id}"
  end
end
