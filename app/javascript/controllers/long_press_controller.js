import { Controller } from "@hotwired/stimulus"

// Long-press on mobile to reveal message actions (reply, edit, delete).
// On desktop, hover still works via CSS group-hover.
export default class extends Controller {
  static targets = ["actions"]

  connect() {
    this.pressTimer = null
    this.isLongPress = false

    // Only attach touch listeners — desktop uses CSS hover
    this.element.addEventListener("touchstart", this.startPress, { passive: true })
    this.element.addEventListener("touchend", this.endPress)
    this.element.addEventListener("touchmove", this.cancelPress, { passive: true })
    this.element.addEventListener("contextmenu", this.preventContext)
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.startPress)
    this.element.removeEventListener("touchend", this.endPress)
    this.element.removeEventListener("touchmove", this.cancelPress)
    this.element.removeEventListener("contextmenu", this.preventContext)
    clearTimeout(this.pressTimer)
  }

  startPress = (e) => {
    this.isLongPress = false
    this.pressTimer = setTimeout(() => {
      this.isLongPress = true
      this.showActions()
    }, 500)
  }

  endPress = (e) => {
    clearTimeout(this.pressTimer)
    // If it was a long press, prevent the tap from navigating
    if (this.isLongPress) {
      e.preventDefault()
    }
  }

  cancelPress = () => {
    clearTimeout(this.pressTimer)
  }

  preventContext = (e) => {
    if (this.isLongPress) {
      e.preventDefault()
    }
  }

  showActions() {
    // Haptic feedback if available
    if (navigator.vibrate) navigator.vibrate(30)

    // Hide any other open action bars first
    document.querySelectorAll("[data-long-press-target='actions'].mobile-actions-visible").forEach((el) => {
      el.classList.remove("mobile-actions-visible")
      el.style.removeProperty("opacity")
    })

    if (this.hasActionsTarget) {
      this.actionsTarget.classList.add("mobile-actions-visible")
      this.actionsTarget.style.opacity = "1"
    }
  }

  // Dismiss when tapping elsewhere (called from a global listener)
  static dismissAll() {
    document.querySelectorAll("[data-long-press-target='actions'].mobile-actions-visible").forEach((el) => {
      el.classList.remove("mobile-actions-visible")
      el.style.removeProperty("opacity")
    })
  }
}

// Dismiss open action bars when tapping outside a message
document.addEventListener("touchstart", (e) => {
  if (!e.target.closest("[data-controller~='long-press']")) {
    const LongPress = window.Stimulus?.getControllerForElementAndIdentifier?.(document.body, "long-press")
    // Fallback: just remove the classes directly
    document.querySelectorAll("[data-long-press-target='actions'].mobile-actions-visible").forEach((el) => {
      el.classList.remove("mobile-actions-visible")
      el.style.removeProperty("opacity")
    })
  }
}, { passive: true })
