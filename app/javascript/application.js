// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"
Turbo.config.drive.prefetchEnabled = false
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
import "controllers"

// When the browser restores a page from bfcache (e.g. mobile swipe-back),
// Turbo Stream subscriptions will have missed updates. Refresh via Turbo.
window.addEventListener("pageshow", (event) => {
  if (event.persisted) {
    Turbo.visit(window.location.href, { action: "replace" })
  }
})

// Dedup guard: the message author gets a direct turbo_stream echo of their own
// create (so it renders instantly), and also still receives the ActionCable
// broadcast of the same message. Drop an append/prepend whose element id already
// exists in the DOM so the author never sees a duplicate. (replace/remove are
// idempotent and don't need this.) Harmless once broadcasts are removed.
document.addEventListener("turbo:before-stream-render", (event) => {
  const stream = event.target
  const action = stream.getAttribute("action")
  if (action !== "append" && action !== "prepend") return

  const firstEl = stream.templateContent?.firstElementChild
  if (firstEl?.id && document.getElementById(firstEl.id)) {
    event.preventDefault()
  }
})
