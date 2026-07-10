import { Controller } from "@hotwired/stimulus"

// Inline lightbox — shows full-size images or videos in an overlay.
export default class extends Controller {
  static values = { src: String, alt: String, type: { type: String, default: "image" } }

  open(e) {
    e.preventDefault()

    this.overlay = document.createElement("div")
    this.overlay.className = "fixed inset-0 z-50 bg-bunker-950/90 flex items-center justify-center p-4 cursor-zoom-out"
    // Suppress poll-driven morph refreshes while open — the overlay isn't in the server
    // render, so a morph would remove it and collapse the enlarged image back to the message.
    this.overlay.setAttribute("data-poll-block", "")

    if (this.typeValue === "video") {
      this.overlay.innerHTML = `
        <video src="${this.srcValue}"
               controls autoplay
               class="max-w-full max-h-full rounded-md shadow-lg cursor-default"
               onclick="event.stopPropagation()"></video>
      `
    } else {
      this.overlay.innerHTML = `
        <img src="${this.srcValue}"
             alt="${this.altValue || ""}"
             class="max-w-full max-h-full object-contain rounded-md shadow-lg" />
      `
    }

    this.overlay.addEventListener("click", this.close)
    document.addEventListener("keydown", this.onKey)
    document.body.appendChild(this.overlay)
  }

  close = () => {
    // Pause video before removing so audio doesn't linger
    const video = this.overlay?.querySelector("video")
    if (video) video.pause()

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
