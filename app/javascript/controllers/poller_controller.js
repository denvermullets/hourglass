import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Polls /poll for a content digest and, when it changes, triggers a Turbo 8 morph
// refresh of the current page (Phase 2 of the WebSocket -> polling migration). Lives on
// <body>, so it is preserved across morphs and connect() runs once — the baseline digest
// is re-read from <meta name="poll-digest"> each tick (morph keeps that meta fresh).
// Fields whose half-typed contents are worth carrying across a morph (an unsubmitted
// "new channel" name). Checkboxes/radios/hidden fields are left to the server render.
const DRAFT_SELECTOR = 'input[type="text"], input[type="search"], input[type="url"], input:not([type]), textarea'

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

    this._drafts = []
    this._onRender = () => {
      this._refreshing = false
      this._restoreDrafts()
    }
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
      return
    }
    this._snapshotDrafts()
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
    // The user is mid-interaction with a field the morph would reset — typing a channel
    // name, or holding an <option> list open (a <select> is focused while its menu is
    // down). Sit this tick out; the next one refreshes once they've moved on.
    if (this._isEditingField()) return

    this._refreshing = true
    this._morphDispatchedAt = ++this._tick
    Turbo.visit(window.location.href, { action: "replace" })
  }

  // Focus sits in an editable control that the morph would rewrite. Fields inside a
  // [data-turbo-permanent] island (the composer) are carried across untouched, so they
  // never need to block.
  _isEditingField() {
    const el = document.activeElement
    if (!el || el === document.body || typeof el.closest !== "function") return false
    if (!el.isContentEditable && !el.matches("input, textarea, select")) return false
    return !el.closest("[data-turbo-permanent]")
  }

  // Text typed but not yet submitted (a half-filled "new channel" box the user has since
  // clicked away from) is reset to the server's value by the morph. Stash those drafts
  // just before the morph and put them back after it — keyed by id, and only for ids that
  // are unambiguous, so a draft can never land in the wrong field.
  _snapshotDrafts() {
    this._drafts = []
    document.querySelectorAll(DRAFT_SELECTOR).forEach((field) => {
      if (!field.id || field.value === field.defaultValue) return
      if (field.closest("[data-turbo-permanent]")) return
      if (document.querySelectorAll(`#${CSS.escape(field.id)}`).length !== 1) return

      this._drafts.push([field.id, field.value])
    })
  }

  _restoreDrafts() {
    if (!this._drafts.length) return

    this._drafts.forEach(([id, value]) => {
      const field = document.getElementById(id)
      if (field) field.value = value
    })
    this._drafts = []
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
