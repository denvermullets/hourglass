import { $createChannelNode } from "lexical/channel_node"

export class ChannelAutocomplete {
  constructor({ editor, lexical, serverId }) {
    this._editor = editor
    this._lexical = lexical
    this._serverId = serverId
    this._dropdown = null
    this._items = null
    this._activeIndex = 0
    this._query = null
    this._nodeKey = null
    this._offset = null
  }

  get isOpen() { return !!this._dropdown }

  checkTrigger(selection) {
    if (!selection.isCollapsed()) {
      this.hideDropdown()
      return
    }

    const anchor = selection.anchor
    const node = anchor.getNode()
    const textContent = node.getTextContent()
    const offset = anchor.offset

    const textBeforeCursor = textContent.substring(0, offset)
    const match = textBeforeCursor.match(/#([a-z0-9-]{0,30})$/)

    if (!match) {
      this.hideDropdown()
      return
    }

    const query = match[1]
    this._query = query
    this._nodeKey = node.getKey()
    this._offset = offset

    const nativeSelection = window.getSelection()
    if (!nativeSelection || nativeSelection.rangeCount === 0) return

    const range = nativeSelection.getRangeAt(0)
    const rect = range.getBoundingClientRect()

    this.fetchChannels(query).then(channels => {
      if (channels.length > 0) {
        this._showDropdown(channels, rect)
      } else {
        this.hideDropdown()
      }
    })
  }

  _showDropdown(channels, anchorRect) {
    this.hideDropdown()

    const dropdown = document.createElement("div")
    dropdown.className = "mention-autocomplete"
    this._activeIndex = 0

    channels.forEach((channel, index) => {
      const item = document.createElement("div")
      item.className = `mention-autocomplete-item${index === 0 ? " active" : ""}`
      item.dataset.channelId = channel.id
      item.dataset.channelName = channel.name

      const nameSpan = document.createElement("span")
      nameSpan.textContent = `#${channel.name}`
      item.appendChild(nameSpan)

      if (channel.description) {
        const descSpan = document.createElement("span")
        descSpan.className = "display-name"
        descSpan.textContent = channel.description
        item.appendChild(descSpan)
      }

      item.addEventListener("mousedown", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this._insertChannel(channel.id, channel.name, channel.server_id)
      })

      item.addEventListener("mouseenter", () => {
        this._setActiveIndex(index)
      })

      dropdown.appendChild(item)
    })

    this._items = channels

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
    const channel = this._items[this._activeIndex]
    if (channel) {
      this._insertChannel(channel.id, channel.name, channel.server_id)
    }
  }

  _insertChannel(channelId, channelName, serverId) {
    this.hideDropdown()

    const nodeKey = this._nodeKey
    const offset = this._offset
    const query = this._query
    const lexical = this._lexical

    this._editor.update(() => {
      const node = lexical.$getNodeByKey(nodeKey)
      if (!node) return

      const textContent = node.getTextContent()
      const triggerStart = offset - query.length - 1

      const channelNode = $createChannelNode(channelId, channelName, serverId)
      const spaceNode = lexical.$createTextNode(" ")

      if (triggerStart === 0 && offset === textContent.length) {
        node.replace(channelNode)
        channelNode.insertAfter(spaceNode)
      } else if (triggerStart === 0) {
        const remaining = node.getTextContent().substring(offset)
        node.setTextContent(remaining)
        node.insertBefore(channelNode)
        channelNode.insertAfter(spaceNode)
      } else {
        const before = textContent.substring(0, triggerStart)
        const after = textContent.substring(offset)
        node.setTextContent(before)
        node.insertAfter(spaceNode)
        node.insertAfter(channelNode)
        if (after) {
          const afterNode = lexical.$createTextNode(after)
          spaceNode.insertAfter(afterNode)
        }
      }

      spaceNode.select()
    })
  }

  async fetchChannels(query) {
    if (!this._serverId) return []

    try {
      const url = `/servers/${this._serverId}/channels/search?q=${encodeURIComponent(query)}`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) return []
      return await response.json()
    } catch {
      return []
    }
  }

  _setActiveIndex(index) {
    const items = this._dropdown?.querySelectorAll(".mention-autocomplete-item")
    if (!items) return

    items.forEach((item, i) => {
      item.classList.toggle("active", i === index)
    })
    this._activeIndex = index
    items[index]?.scrollIntoView({ block: "nearest" })
  }

  destroy() {
    this.hideDropdown()
  }
}
