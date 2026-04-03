import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["banner"]

  connect() {
    this._wasDisconnected = false
    this._consumer = createConsumer()

    this._subscription = this._consumer.subscriptions.create(
      { channel: "ConnectionMonitorChannel" },
      {
        connected: () => this._onConnected(),
        disconnected: () => this._onDisconnected(),
        rejected: () => this._onDisconnected()
      }
    )

    this._onVisibilityChange = () => this._handleVisibilityChange()
    document.addEventListener("visibilitychange", this._onVisibilityChange)
  }

  _onConnected() {
    this._hideBanner()

    if (this._wasDisconnected) {
      this._wasDisconnected = false
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }

  _onDisconnected() {
    this._wasDisconnected = true
    this._showBanner()
  }

  _handleVisibilityChange() {
    if (document.visibilityState === "visible" && this._wasDisconnected) {
      this._consumer.connect()
    }
  }

  _showBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove("hidden")
    }
  }

  _hideBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.add("hidden")
    }
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this._onVisibilityChange)

    if (this._subscription) {
      this._subscription.unsubscribe()
      this._subscription = null
    }
  }
}
