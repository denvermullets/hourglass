import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "loadOlder"]

  connect() {
    this.scrollToBottom()
    this.observeNewMessages()
  }

  scrollToBottom() {
    const container = this.containerTarget
    container.scrollTop = container.scrollHeight
  }

  observeNewMessages() {
    const messages = this.containerTarget.querySelector("#messages")
    if (!messages) return

    this.mutationObserver = new MutationObserver(() => {
      if (this.isNearBottom()) {
        this.scrollToBottom()
      }
    })

    this.mutationObserver.observe(messages, { childList: true })
  }

  isNearBottom() {
    const container = this.containerTarget
    const threshold = 150
    return container.scrollHeight - container.scrollTop - container.clientHeight < threshold
  }

  // Preserve scroll position when older messages are prepended
  preserveScroll() {
    const container = this.containerTarget
    const previousHeight = container.scrollHeight
    requestAnimationFrame(() => {
      container.scrollTop = container.scrollHeight - previousHeight
    })
  }

  disconnect() {
    this.mutationObserver?.disconnect()
  }
}
