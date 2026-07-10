import { mentionProvider, channelProvider, slashProvider } from "composer/typeahead_providers"

// Coordinates the three textarea typeahead dropdowns (@mention, #channel,
// /slash). At most one is open at a time. Owned by message_input_controller,
// which forwards input / keydown / blur and reads back nothing — selection
// splices plain markdown directly into the textarea value.
export class TextareaTypeahead {
  constructor({ textarea, serverId, channelId, channelLinked }) {
    this.textarea = textarea
    this.providers = [
      mentionProvider({ channelId }),
      channelProvider({ serverId }),
      slashProvider({ linked: channelLinked }),
    ]

    this.dropdown = null
    this.items = null
    this.activeIndex = 0
    this.provider = null
    this.range = null
    this._reqId = 0
  }

  get isOpen() {
    return !!this.dropdown
  }

  // Recompute the active trigger whenever the text changes.
  onInput() {
    const caret = this.textarea.selectionStart
    const text = this.textarea.value
    const reqId = ++this._reqId

    for (const provider of this.providers) {
      if (provider.enabled === false) continue
      const range = provider.match(text, caret)
      if (!range) continue

      this.provider = provider
      this.range = range
      provider.fetch(range.query).then((items) => {
        // Ignore stale responses and ones the user has typed past.
        if (reqId !== this._reqId) return
        if (items && items.length > 0) this._show(items)
        else this.hide()
      })
      return
    }

    this.hide()
  }

  // Returns true when the key was consumed by an open dropdown.
  handleKeydown(event) {
    if (!this.isOpen) return false

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this._nav(1)
        return true
      case "ArrowUp":
        event.preventDefault()
        this._nav(-1)
        return true
      case "Enter":
      case "Tab":
        event.preventDefault()
        this._selectActive()
        return true
      case "Escape":
        event.preventDefault()
        this.hide()
        return true
      default:
        return false
    }
  }

  hide() {
    if (!this.dropdown) return
    this.dropdown.remove()
    this.dropdown = null
    this.items = null
    this.activeIndex = 0
  }

  destroy() {
    this.hide()
  }

  // Private

  _show(items) {
    this.hide()

    const dropdown = document.createElement("div")
    dropdown.className = "mention-autocomplete"
    if (this.provider.dropdownClass) dropdown.classList.add(this.provider.dropdownClass)
    // Suppress poll-driven morph refreshes while the popup is open — a morph would tear down
    // the composer/popup mid-typing. Removed automatically when hide() removes the node.
    dropdown.setAttribute("data-poll-block", "")

    items.forEach((item, index) => {
      const el = document.createElement("div")
      el.className = `mention-autocomplete-item${index === 0 ? " active" : ""}`
      this.provider.itemChildren(item).forEach((child) => el.appendChild(child))

      el.addEventListener("mousedown", (event) => {
        // Keep focus in the textarea so the selection splice lands correctly.
        event.preventDefault()
        event.stopPropagation()
        this._select(item)
      })
      el.addEventListener("mouseenter", () => this._setActiveIndex(index))

      dropdown.appendChild(el)
    })

    // Anchor above the textarea (a textarea exposes no DOM caret rect).
    const rect = this.textarea.getBoundingClientRect()
    dropdown.style.position = "fixed"
    dropdown.style.left = `${rect.left}px`
    dropdown.style.bottom = `${window.innerHeight - rect.top + 4}px`
    dropdown.style.maxWidth = `${Math.max(rect.width, 200)}px`

    document.body.appendChild(dropdown)
    this.dropdown = dropdown
    this.items = items
    this.activeIndex = 0
  }

  _nav(direction) {
    const max = this.items.length - 1
    const next = this.activeIndex + direction
    this._setActiveIndex(Math.max(0, Math.min(next, max)))
  }

  _setActiveIndex(index) {
    if (!this.dropdown) return
    const els = this.dropdown.querySelectorAll(".mention-autocomplete-item")
    els.forEach((el, i) => el.classList.toggle("active", i === index))
    this.activeIndex = index
    els[index]?.scrollIntoView({ block: "nearest" })
  }

  _selectActive() {
    if (!this.items) return
    const item = this.items[this.activeIndex]
    if (item) this._select(item)
  }

  _select(item) {
    const replacement = this.provider.replacement(item)
    const { start, end } = this.range
    const value = this.textarea.value

    this.textarea.value = value.slice(0, start) + replacement + value.slice(end)
    const caret = start + replacement.length
    this.textarea.selectionStart = caret
    this.textarea.selectionEnd = caret

    this.hide()
    this.textarea.focus()
    // Notify the controller so it re-grows the textarea (and re-checks triggers,
    // which now find the trailing space and stay closed).
    this.textarea.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
