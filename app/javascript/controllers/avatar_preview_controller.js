import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "box", "image", "placeholder"]

  preview() {
    const file = this.inputTarget.files[0]
    if (!file) return

    const validTypes = ["image/jpeg", "image/png"]
    if (!validTypes.includes(file.type)) {
      this.inputTarget.value = ""
      return
    }

    const maxSize = 2 * 1024 * 1024
    if (file.size > maxSize) {
      this.inputTarget.value = ""
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      this.imageTarget.src = e.target.result
      this.imageTarget.classList.remove("hidden")
      this.placeholderTargets.forEach(el => el.classList.add("hidden"))
    }
    reader.readAsDataURL(file)
  }
}
