import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { currentUser: Number }

  connect() {
    this.showAuthorActions()
    this.observer = new MutationObserver(() => this.showAuthorActions())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  showAuthorActions() {
    this.element.querySelectorAll("[data-author-only]").forEach((el) => {
      const messageEl = el.closest("[data-message-author-id]")
      if (!messageEl) return

      const authorId = parseInt(messageEl.dataset.messageAuthorId, 10)
      if (authorId === this.currentUserValue) {
        el.classList.remove("hidden")
      } else {
        el.classList.add("hidden")
      }
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
