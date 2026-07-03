import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "loadOlder"]

  connect() {
    this._wasNearBottom = true

    if (this._scrollToAnchor()) {
      // Scrolled to a specific message from URL hash
    } else {
      this.scrollToBottom()
    }

    this.observeNewMessages()
    this._onScroll = () => {
      this._wasNearBottom = this.isNearBottom()
      this._syncPollBlock()
    }
    this.containerTarget.addEventListener("scroll", this._onScroll, { passive: true })
    this._syncPollBlock()
  }

  // Block poll-driven morph refreshes while the user is scrolled up (reading history or
  // viewing loaded-older messages), so a morph doesn't drop them or jump the reader.
  // Near the bottom, refreshes flow through and new messages stick.
  _syncPollBlock() {
    if (this._wasNearBottom) {
      this.containerTarget.removeAttribute("data-poll-block")
    } else {
      this.containerTarget.setAttribute("data-poll-block", "")
    }
  }

  scrollToBottom() {
    const container = this.containerTarget
    container.scrollTop = container.scrollHeight
    this._wasNearBottom = true
  }

  observeNewMessages() {
    const messages = this.containerTarget.querySelector("#messages") || this.containerTarget.querySelector("#thread_replies")
    if (!messages) return

    this.mutationObserver = new MutationObserver((mutations) => {
      const hasNewNodes = mutations.some(m => m.addedNodes.length > 0)
      if (hasNewNodes && this._wasNearBottom) {
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

  _scrollToAnchor() {
    const hash = window.location.hash
    if (!hash?.startsWith("#message_")) return false

    const target = this.containerTarget.querySelector(hash)
    if (!target) return false

    target.scrollIntoView({ block: "center" })
    target.classList.add("bg-granny-smith-apple-600/10")
    setTimeout(() => target.classList.remove("bg-granny-smith-apple-600/10"), 2000)
    return true
  }

  disconnect() {
    this.mutationObserver?.disconnect()
    if (this._onScroll) {
      this.containerTarget.removeEventListener("scroll", this._onScroll)
    }
    this.containerTarget.removeAttribute("data-poll-block")
  }
}
