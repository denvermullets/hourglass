import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  preview(event) {
    document.documentElement.dataset.theme = event.target.value
    const link = document.querySelector('link[rel="icon"][type="image/svg+xml"]')
    if (link) link.href = `/icons/${event.target.value}.svg`
  }

  previewTextSize(event) {
    document.documentElement.dataset.textSize = event.target.value
  }

  previewTextSizeMobile(event) {
    document.documentElement.dataset.textSizeMobile = event.target.value
  }
}
