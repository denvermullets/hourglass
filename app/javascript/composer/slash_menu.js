export class SlashMenu {
  constructor({ editor, lexical, linked, commands }) {
    this._editor = editor
    this._lexical = lexical
    this._linked = !!linked
    this._commands = commands || []
    this._dropdown = null
    this._items = null
    this._activeIndex = 0
    this._query = null
  }

  get isOpen() { return !!this._dropdown }

  checkTrigger(selection) {
    if (!this._linked) {
      this.hideDropdown()
      return
    }
    if (!selection.isCollapsed()) {
      this.hideDropdown()
      return
    }

    const anchor = selection.anchor
    const node = anchor.getNode()
    const root = this._lexical.$getRoot()
    const paragraph = node.getTopLevelElement()
    if (!paragraph || paragraph !== root.getFirstChild()) {
      this.hideDropdown()
      return
    }

    const paragraphText = paragraph.getTextContent()
    const match = paragraphText.match(/^\/(\w*)$/)
    if (!match) {
      this.hideDropdown()
      return
    }

    this._query = match[1]
    const filtered = this._commands.filter(c => c.name.startsWith(this._query))
    if (filtered.length === 0) {
      this.hideDropdown()
      return
    }

    const nativeSelection = window.getSelection()
    if (!nativeSelection || nativeSelection.rangeCount === 0) return
    const rect = nativeSelection.getRangeAt(0).getBoundingClientRect()
    this._showDropdown(filtered, rect)
  }

  _showDropdown(commands, anchorRect) {
    this.hideDropdown()

    const dropdown = document.createElement("div")
    dropdown.className = "mention-autocomplete slash-menu"
    this._activeIndex = 0

    commands.forEach((command, index) => {
      const item = document.createElement("div")
      item.className = `mention-autocomplete-item${index === 0 ? " active" : ""}`
      item.dataset.commandName = command.name

      const usageSpan = document.createElement("span")
      usageSpan.className = "slash-menu-usage"
      usageSpan.textContent = command.usage
      item.appendChild(usageSpan)

      const descSpan = document.createElement("span")
      descSpan.className = "display-name slash-menu-desc"
      descSpan.textContent = `— ${command.description}`
      item.appendChild(descSpan)

      item.addEventListener("mousedown", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this._insertCommand(command.name)
      })
      item.addEventListener("mouseenter", () => this._setActiveIndex(index))

      dropdown.appendChild(item)
    })

    this._items = commands

    dropdown.style.position = "fixed"
    dropdown.style.left = `${anchorRect.left}px`
    dropdown.style.bottom = `${window.innerHeight - anchorRect.top + 4}px`

    document.body.appendChild(dropdown)
    this._dropdown = dropdown
  }

  hideDropdown() {
    if (this._dropdown) {
      this._dropdown.remove()
      this._dropdown = null
      this._items = null
      this._activeIndex = 0
    }
  }

  handleNav(event, direction) {
    if (!this._dropdown || !this._items) return false

    event.preventDefault()
    const items = this._dropdown.querySelectorAll(".mention-autocomplete-item")
    const max = items.length - 1

    if (direction === "down") {
      this._setActiveIndex(Math.min(this._activeIndex + 1, max))
    } else {
      this._setActiveIndex(Math.max(this._activeIndex - 1, 0))
    }

    return true
  }

  selectActive() {
    if (!this._items || this._activeIndex == null) return
    const command = this._items[this._activeIndex]
    if (command) this._insertCommand(command.name)
  }

  _insertCommand(name) {
    this.hideDropdown()
    const lexical = this._lexical

    this._editor.update(() => {
      const root = lexical.$getRoot()
      const paragraph = root.getFirstChild()
      if (!paragraph) return
      paragraph.clear()
      const textNode = lexical.$createTextNode(`/${name} `)
      paragraph.append(textNode)
      textNode.select()
    })
  }

  _setActiveIndex(index) {
    const items = this._dropdown?.querySelectorAll(".mention-autocomplete-item")
    if (!items) return

    items.forEach((item, i) => item.classList.toggle("active", i === index))
    this._activeIndex = index
    items[index]?.scrollIntoView({ block: "nearest" })
  }

  destroy() {
    this.hideDropdown()
  }
}
