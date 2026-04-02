import { Controller } from "@hotwired/stimulus"

// Tap on mobile to toggle message actions (reply, edit, delete).
// On desktop, hover still works via CSS group-hover.
export default class extends Controller {
  static targets = ["actions"]

  connect() {
    this.element.addEventListener("click", this.toggle)
  }

  disconnect() {
    this.element.removeEventListener("click", this.toggle)
  }

  toggle = (e) => {
    // Only on touch devices — desktop uses CSS hover
    if (!matchMedia("(hover: none)").matches) return

    // Don't intercept taps on links/buttons (reply, edit, delete, thread links)
    if (e.target.closest("a, button")) return

    e.preventDefault()

    const isVisible = this.hasActionsTarget &&
      this.actionsTarget.classList.contains("mobile-actions-visible")

    // Dismiss all open action bars first
    dismissAll()

    // Toggle this one
    if (!isVisible && this.hasActionsTarget) {
      this.actionsTarget.classList.add("mobile-actions-visible")
      this.actionsTarget.style.opacity = "1"
    }
  }
}

function dismissAll() {
  document.querySelectorAll("[data-long-press-target='actions'].mobile-actions-visible").forEach((el) => {
    el.classList.remove("mobile-actions-visible")
    el.style.removeProperty("opacity")
  })
}

// Dismiss when tapping outside any message
document.addEventListener("click", (e) => {
  if (!e.target.closest("[data-controller~='long-press']")) {
    dismissAll()
  }
})
