import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { base: String }

  connect() {
    this._observer = new MutationObserver(() => this._update())
    this._observer.observe(this.element, { childList: true, subtree: true })
    this._update()
  }

  disconnect() {
    this._observer?.disconnect()
  }

  _update() {
    const hasUnread = this.element.querySelector("[data-unread]") !== null
    document.title = hasUnread ? `● ${this.baseValue}` : this.baseValue
  }
}
