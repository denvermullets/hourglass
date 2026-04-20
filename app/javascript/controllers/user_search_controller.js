import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "selectedUsers"]
  static values = { url: String }

  connect() {
    this.selectedUsers = new Map()
    this.timeout = null
  }

  search() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      return
    }

    this.timeout = setTimeout(() => {
      fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "text/html" }
      })
        .then(response => response.text())
        .then(html => {
          this.resultsTarget.innerHTML = html
        })
    }, 300)
  }

  selectUser(event) {
    const button = event.currentTarget
    const userId = button.dataset.userId
    const username = button.dataset.username

    if (this.selectedUsers.has(userId)) return

    this.selectedUsers.set(userId, username)
    this.renderSelectedUsers()

    this.inputTarget.value = ""
    this.resultsTarget.innerHTML = ""
    this.inputTarget.focus()
  }

  removeUser(event) {
    const userId = event.currentTarget.dataset.userId
    this.selectedUsers.delete(userId)
    this.renderSelectedUsers()
  }

  renderSelectedUsers() {
    const container = this.selectedUsersTarget
    container.innerHTML = ""

    this.selectedUsers.forEach((username, userId) => {
      const chip = document.createElement("div")
      chip.className = "flex items-center gap-1 bg-bunker-875 border border-bunker-825 rounded px-2 py-1 text-xs text-bunker-200"
      chip.innerHTML = `
        <span>${username}</span>
        <input type="hidden" name="user_ids[]" value="${userId}">
        <button type="button" class="text-bunker-500 hover:text-bunker-300 ml-1 cursor-pointer bg-transparent border-0 p-0 text-xs" data-action="click->user-search#removeUser" data-user-id="${userId}">&times;</button>
      `
      container.appendChild(chip)
    })
  }
}
