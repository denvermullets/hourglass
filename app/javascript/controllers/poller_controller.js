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
    // A message send optimistically appends the message to the DOM (the "echo") before the
    // poll digest catches up. A morph refresh built from a pre-send DB snapshot would remove
    // that echoed node — so we (1) block new morphs while a send is in flight, and (2) discard
    // any morph whose fetch was dispatched before the most recent send.
    this._sends = 0            // count of message sends currently in flight (block new morphs)
    this._lastSendAt = 0       // monotonic tick of the most recent send start
    this._morphDispatchedAt = 0 // monotonic tick when the in-flight morph was started
    this._tick = 0             // monotonic counter (avoids Date.now / clock issues)

    this._onVisibility = () => this._handleVisibility()
    document.addEventListener("visibilitychange", this._onVisibility)

    this._onRender = () => { this._refreshing = false }
    document.addEventListener("turbo:render", this._onRender)

    this._onSubmitStart = (e) => this._handleSubmitStart(e)
    document.addEventListener("turbo:submit-start", this._onSubmitStart)

    this._onSubmitEnd = (e) => this._handleSubmitEnd(e)
    document.addEventListener("turbo:submit-end", this._onSubmitEnd)

    this._onBeforeRender = (e) => this._handleBeforeRender(e)
    document.addEventListener("turbo:before-render", this._onBeforeRender)

    if (!document.hidden) this._start()
  }

  disconnect() {
    this._stop()
    document.removeEventListener("visibilitychange", this._onVisibility)
    document.removeEventListener("turbo:render", this._onRender)
    document.removeEventListener("turbo:submit-start", this._onSubmitStart)
    document.removeEventListener("turbo:submit-end", this._onSubmitEnd)
    document.removeEventListener("turbo:before-render", this._onBeforeRender)
  }

  // (1) A message-compose submit started: hold off morphs until it resolves so the echo isn't
  // clobbered, and stamp the send so an already-in-flight morph can recognize it's now stale.
  _handleSubmitStart(event) {
    if (!this._isMessageSubmit(event)) return
    this._sends += 1
    this._lastSendAt = ++this._tick
  }

  _handleSubmitEnd(event) {
    if (!this._isMessageSubmit(event)) return
    this._sends = Math.max(0, this._sends - 1)
  }

  // (2) A morph is about to render. If it's a poll morph we started before the latest send, its
  // server render predates the new message and would erase the echoed node — cancel it. The next
  // poll (digest now changed) will morph from a fresh snapshot that includes the message.
  _handleBeforeRender(event) {
    if (!this._refreshing) return // only poll-driven morphs; leave real navigations alone
    if (this._lastSendAt > this._morphDispatchedAt) {
      event.preventDefault()
      this._refreshing = false
    }
  }

  _isMessageSubmit(event) {
    const form = event.detail?.formSubmission?.formElement
    return !!form && form.matches('[data-controller~="message-input"]')
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
    // A message send is in flight: its echo isn't in the server render yet, so a morph now
    // would erase it. Wait for the send to finish; the next tick refreshes cleanly.
    if (this._sends > 0) return
    // A transient island (open menu, active upload, scrolled-up reading) wants us to wait.
    if (document.querySelector("[data-poll-block]")) return

    this._refreshing = true
    this._morphDispatchedAt = ++this._tick
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
