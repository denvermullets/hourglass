import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  submit(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }

  reset() {
    this.element.reset()
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }
}
