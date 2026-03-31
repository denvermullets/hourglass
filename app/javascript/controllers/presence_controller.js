import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { serverId: Number }

  connect() {
    this.subscription = createConsumer().subscriptions.create(
      { channel: "PresenceChannel", server_id: this.serverIdValue },
      { connected: () => {}, disconnected: () => {}, received: () => {} }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }
}
