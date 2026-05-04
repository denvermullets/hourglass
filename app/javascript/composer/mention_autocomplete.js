import { $createMentionNode } from "lexical/mention_node"

export class MentionAutocomplete {
  constructor({ editor, lexical, channelId }) {
    this._editor = editor
    this._lexical = lexical
    this._channelId = channelId
    this._dropdown = null
    this._members = null
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
    const match = textBeforeCursor.match(/@([\w.+\-@]{0,64})$/)

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

    if (query.length >= 1) {
      this.fetchMembers(query).then(members => {
        if (members.length > 0) {
          this._showDropdown(members, rect)
        } else {
          this.hideDropdown()
        }
      })
    } else {
      this.fetchMembers("").then(members => {
        if (members.length > 0) {
          this._showDropdown(members, rect)
        }
      })
    }
  }

  _showDropdown(members, anchorRect) {
    this.hideDropdown()

    const dropdown = document.createElement("div")
    dropdown.className = "mention-autocomplete"
    this._activeIndex = 0

    members.forEach((member, index) => {
      const item = document.createElement("div")
      item.className = `mention-autocomplete-item${index === 0 ? " active" : ""}`
      item.dataset.username = member.username

      const nameSpan = document.createElement("span")
      nameSpan.textContent = `@${member.username}`
      item.appendChild(nameSpan)

      if (member.display_name && member.display_name !== member.username) {
        const displaySpan = document.createElement("span")
        displaySpan.className = "display-name"
        displaySpan.textContent = member.display_name
        item.appendChild(displaySpan)
      }

      if (member.external) {
        const badge = document.createElement("span")
        badge.className = "mention-external-badge"
        badge.textContent = "external"
        item.appendChild(badge)
      }

      item.addEventListener("mousedown", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this._insertMention(member)
      })

      item.addEventListener("mouseenter", () => {
        this._setActiveIndex(index)
      })

      dropdown.appendChild(item)
    })

    this._members = members

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
      this._members = null
      this._activeIndex = 0
    }
  }

  handleNav(event, direction) {
    if (!this._dropdown || !this._members) return false

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
    if (!this._members || this._activeIndex == null) return
    const member = this._members[this._activeIndex]
    if (member) {
      this._insertMention(member)
    }
  }

  _insertMention(member) {
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

      const mentionNode = $createMentionNode(member.username, {
        external: !!member.external,
        mtasksUserId: member.mtasks_user_id ?? null
      })
      const spaceNode = lexical.$createTextNode(" ")

      if (triggerStart === 0 && offset === textContent.length) {
        node.replace(mentionNode)
        mentionNode.insertAfter(spaceNode)
      } else if (triggerStart === 0) {
        const remaining = node.getTextContent().substring(offset)
        node.setTextContent(remaining)
        node.insertBefore(mentionNode)
        mentionNode.insertAfter(spaceNode)
      } else {
        const before = textContent.substring(0, triggerStart)
        const after = textContent.substring(offset)
        node.setTextContent(before)
        node.insertAfter(spaceNode)
        node.insertAfter(mentionNode)
        if (after) {
          const afterNode = lexical.$createTextNode(after)
          spaceNode.insertAfter(afterNode)
        }
      }

      spaceNode.select()
    })
  }

  async fetchMembers(query) {
    if (!this._channelId) return []

    try {
      const url = `/mentions/search?q=${encodeURIComponent(query)}&channel_id=${encodeURIComponent(this._channelId)}`
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
