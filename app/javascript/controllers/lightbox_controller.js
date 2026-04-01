import { Controller } from "@hotwired/stimulus"

// Inline image lightbox — shows full-size image in an overlay instead
// of navigating to the raw S3 URL (which triggers browser security warnings).
export default class extends Controller {
  static values = { src: String, alt: String }

  open(e) {
    e.preventDefault()

    this.overlay = document.createElement("div")
    this.overlay.className = "fixed inset-0 z-50 bg-bunker-950/90 flex items-center justify-center p-4 cursor-zoom-out"
    this.overlay.innerHTML = `
      <img src="${this.srcValue}"
           alt="${this.altValue || ""}"
           class="max-w-full max-h-full object-contain rounded-md shadow-lg" />
    `
    this.overlay.addEventListener("click", this.close)
    document.addEventListener("keydown", this.onKey)
    document.body.appendChild(this.overlay)
  }

  close = () => {
    document.removeEventListener("keydown", this.onKey)
    this.overlay?.remove()
    this.overlay = null
  }

  onKey = (e) => {
    if (e.key === "Escape") this.close()
  }

  disconnect() {
    this.close()
  }
}
