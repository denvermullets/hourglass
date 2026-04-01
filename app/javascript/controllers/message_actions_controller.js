import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { currentUser: Number }

  connect() {
    this.showAuthorActions()
    this.observer = new MutationObserver(() => this.showAuthorActions())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  showAuthorActions() {
    this.element.querySelectorAll("[data-message-author-id]").forEach((messageEl) => {
      const authorId = parseInt(messageEl.dataset.messageAuthorId, 10)
      const isAuthor = authorId === this.currentUserValue

      // Show/hide edit/delete actions
      messageEl.querySelectorAll("[data-author-only]").forEach((el) => {
        if (isAuthor) {
          el.classList.remove("hidden")
          el.classList.add("flex")
        } else {
          el.classList.remove("flex")
          el.classList.add("hidden")
        }
      })

      // Color username: green for current user, blue for others
      messageEl.querySelectorAll("[data-author-name]").forEach((el) => {
        if (isAuthor) {
          el.classList.remove("text-jordy-blue-400")
          el.classList.add("text-granny-smith-apple-300")
        } else {
          el.classList.remove("text-granny-smith-apple-300")
          el.classList.add("text-jordy-blue-400")
        }
      })
    })
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
