import { Controller } from "@hotwired/stimulus"

// Re-applies active channel highlight after Turbo Stream replacements
export default class extends Controller {
  connect() {
    this.observer = new MutationObserver(() => this.highlightActive())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  highlightActive() {
    const path = window.location.pathname
    const links = this.element.querySelectorAll("a[href]")
    for (const link of links) {
      if (link.pathname === path) {
        link.className = link.className
          .replace(/text-bunker-400/, "text-bunker-050")
          .replace(/hover:bg-bunker-900 hover:text-bunker-200/, "bg-bunker-875")
        if (!link.querySelector(".absolute")) {
          const bar = document.createElement("span")
          bar.className = "absolute left-0 top-1 bottom-1 w-0.5 rounded-r bg-granny-smith-apple-300"
          link.appendChild(bar)
        }
      }
    }
  }
}
