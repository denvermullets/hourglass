import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  preview(event) {
    document.documentElement.dataset.theme = event.target.value
  }

  previewTextSize(event) {
    document.documentElement.dataset.textSize = event.target.value
  }

  previewTextSizeMobile(event) {
    document.documentElement.dataset.textSizeMobile = event.target.value
  }
}
