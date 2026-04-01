import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "NotificationsChannel" },
      {
        received: (data) => {
          if (data.html) {
            // Use dynamic import to avoid load-order issues
            import("@hotwired/turbo-rails").then(({ Turbo }) => {
              Turbo.renderStreamMessage(data.html)
            }).catch(() => {
              // Fallback: try global Turbo
              if (window.Turbo) {
                window.Turbo.renderStreamMessage(data.html)
              }
            })
          }
        }
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    if (this.consumer) {
      this.consumer.disconnect()
      this.consumer = null
    }
  }
}
