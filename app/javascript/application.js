// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"
Turbo.config.drive.prefetchEnabled = false
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
import "controllers"

// When the browser restores a page from bfcache (e.g. mobile swipe-back), the page may
// be stale (the poller was paused). Refresh via Turbo so the next poll starts fresh.
window.addEventListener("pageshow", (event) => {
  if (event.persisted) {
    Turbo.visit(window.location.href, { action: "replace" })
  }
})
