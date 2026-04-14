import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "bar", "label"]

  evaluate() {
    const password = this.inputTarget.value
    const { width, color, text } = this.strength(password)

    this.barTarget.style.width = width
    this.barTarget.className = `rounded-sm h-1 transition-all duration-200 ${color}`
    this.labelTarget.textContent = text
    this.labelTarget.className = `text-[8px] tracking-[0.08em] ${color.replace("bg-", "text-")}`
  }

  strength(password) {
    const len = password.length

    if (len === 0) return { width: "0%", color: "", text: "" }
    if (len < 8)   return { width: "25%", color: "bg-danger-400", text: "weak" }
    if (len < 12)  return { width: "50%", color: "bg-yellow-400", text: "fair" }
    if (len < 16)  return { width: "75%", color: "bg-jordy-blue-400", text: "good" }

    return { width: "100%", color: "bg-granny-smith-apple-400", text: "strong" }
  }
}
