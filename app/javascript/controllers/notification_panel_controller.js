import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "overlay"]

  connect() {
    this._handleKeydown = this._handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleKeydown)
  }

  toggle() {
    if (this.panelTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.panelTarget.classList.remove("hidden")
    this.overlayTarget.classList.remove("hidden")
    // Defer poll-driven morph refreshes while the panel is open.
    this.panelTarget.setAttribute("data-poll-block", "")

    this._loadNotifications()
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.overlayTarget.classList.add("hidden")
    this.panelTarget.removeAttribute("data-poll-block")
  }

  _loadNotifications() {
    const content = this.panelTarget.querySelector("[data-notification-panel-target='content']")
    if (!content) return

    fetch("/notifications", {
      headers: { "Accept": "text/html" }
    })
      .then(response => response.text())
      .then(html => {
        content.innerHTML = html
        this._bindPanelEvents(content)
      })
  }

  _bindPanelEvents(container) {
    // Bind "mark all read" link
    const markAllLink = container.querySelector("[data-mark-all-read]")
    if (markAllLink) {
      markAllLink.addEventListener("click", (e) => {
        e.preventDefault()
        this._markAllRead()
      })
    }

    // Bind notification item clicks — navigate + mark read
    container.querySelectorAll("[data-notification-link]").forEach(link => {
      link.addEventListener("click", (e) => {
        const notificationId = link.dataset.notificationId
        if (notificationId) {
          this._markRead(notificationId)
        }
        this.close()
        // Let the link navigate normally via href
      })
    })
  }

  _markRead(notificationId) {
    fetch(`/notifications/${notificationId}/mark_read`, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": this._csrfToken(),
        "Accept": "text/html"
      }
    })
  }

  _markAllRead() {
    fetch("/notifications/mark_all_read", {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": this._csrfToken(),
        "Accept": "text/html"
      }
    }).then(() => {
      this._loadNotifications()
    })
  }

  _csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  _handleKeydown(event) {
    if (event.key === "Escape" && !this.panelTarget.classList.contains("hidden")) {
      this.close()
    }
  }
}
