import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Polls /poll for a content digest and, when it changes, triggers a Turbo 8 morph
// refresh of the current page (Phase 2 of the WebSocket -> polling migration). Lives on
// <body>, so it is preserved across morphs and connect() runs once — the baseline digest
// is re-read from <meta name="poll-digest"> each tick (morph keeps that meta fresh).
export default class extends Controller {
  static values = {
    url: String,
    channelId: Number,
    conversationId: Number,
    threadId: Number,
    interval: { type: Number, default: 4000 }
  }

  connect() {
    this._failures = 0
    this._refreshing = false

    this._onVisibility = () => this._handleVisibility()
    document.addEventListener("visibilitychange", this._onVisibility)

    this._onRender = () => { this._refreshing = false }
    document.addEventListener("turbo:render", this._onRender)

    if (!document.hidden) this._start()
  }

  disconnect() {
    this._stop()
    document.removeEventListener("visibilitychange", this._onVisibility)
    document.removeEventListener("turbo:render", this._onRender)
  }

  _handleVisibility() {
    if (document.hidden) {
      this._stop()
    } else if (!this._timer) {
      this._failures = 0
      this._start()
    }
  }

  _start() {
    this._stop()
    this._timer = setInterval(() => this._poll(), this._currentInterval())
  }

  _stop() {
    if (this._timer) {
      clearInterval(this._timer)
      this._timer = null
    }
  }

  async _poll() {
    if (document.hidden) return

    try {
      const response = await fetch(this._pollUrl(), {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`poll ${response.status}`)

      const { digest } = await response.json()
      this._onSuccess()
      this._maybeRefresh(digest)
    } catch {
      this._onError()
    }
  }

  _maybeRefresh(digest) {
    if (this._refreshing) return
    if (!digest || digest === this._currentDigest()) return
    // A transient island (open menu, active upload, scrolled-up reading) wants us to wait.
    if (document.querySelector("[data-poll-block]")) return

    this._refreshing = true
    Turbo.visit(window.location.href, { action: "replace" })
  }

  _currentDigest() {
    return document.querySelector('meta[name="poll-digest"]')?.content
  }

  _pollUrl() {
    const url = new URL(this.urlValue, window.location.origin)
    if (this.channelIdValue > 0) url.searchParams.set("channel_id", this.channelIdValue)
    if (this.conversationIdValue > 0) url.searchParams.set("conversation_id", this.conversationIdValue)
    if (this.threadIdValue > 0) url.searchParams.set("thread_id", this.threadIdValue)
    return url.toString()
  }

  // Steady cadence on success; exponential backoff (capped) after consecutive errors.
  _currentInterval() {
    if (this._failures === 0) return this.intervalValue
    return Math.min(this.intervalValue * 2 ** this._failures, 30000)
  }

  _onSuccess() {
    if (this._failures !== 0) {
      this._failures = 0
      this._start()
    }
  }

  _onError() {
    this._failures += 1
    this._start()
  }
}
