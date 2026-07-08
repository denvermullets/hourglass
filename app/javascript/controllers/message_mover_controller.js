import { Controller } from "@hotwired/stimulus"

// Admin action: move a root message (and its thread) to another channel.
// A single dialog lives in the channel view; each message's "move" button opens it
// and records which message to move. Picking a channel submits the move form.
export default class extends Controller {
  static targets = ["dialog", "search", "channel", "form", "channelInput"]
  static values = { messagesBaseUrl: String }

  connect() {
    // While the picker is open, block the poll-driven Turbo morph — a refresh would
    // morph the dialog out from under the admin and dismiss it. The poller skips
    // refreshing whenever any [data-poll-block] element is present. The native "close"
    // event covers every dismissal path (Escape, close button, submit).
    this._onClose = () => this.dialogTarget.removeAttribute("data-poll-block")
    this.dialogTarget.addEventListener("close", this._onClose)
  }

  disconnect() {
    this.dialogTarget.removeEventListener("close", this._onClose)
  }

  open(event) {
    this.messageId = event.currentTarget.dataset.messageId
    this.searchTarget.value = ""
    this.filter()
    this.dialogTarget.setAttribute("data-poll-block", "")
    this.dialogTarget.showModal()
    this.searchTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  filter() {
    const q = this.searchTarget.value.trim().toLowerCase()
    this.channelTargets.forEach((el) => {
      const name = (el.dataset.name || "").toLowerCase()
      el.classList.toggle("hidden", q !== "" && !name.includes(q))
    })
  }

  pick(event) {
    if (!this.messageId) return
    this.channelInputTarget.value = event.currentTarget.dataset.channelId
    this.formTarget.action = `${this.messagesBaseUrlValue}/${this.messageId}/move`
    this.formTarget.requestSubmit()
  }
}
