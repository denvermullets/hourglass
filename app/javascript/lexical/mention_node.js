import { TextNode } from "lexical"

export class MentionNode extends TextNode {
  __username
  __external
  __mtasksUserId

  static getType() {
    return "mention"
  }

  static clone(node) {
    return new MentionNode(node.__username, node.__external, node.__mtasksUserId, node.__text, node.__key)
  }

  constructor(username, external, mtasksUserId, text, key) {
    super(text ?? `@${username}`, key)
    this.__username = username
    this.__external = !!external
    this.__mtasksUserId = mtasksUserId ?? null
  }

  createDOM(config) {
    const span = super.createDOM(config)
    this._applyAttrs(span)
    return span
  }

  updateDOM(prevNode, dom, config) {
    const updated = super.updateDOM(prevNode, dom, config)
    this._applyAttrs(dom)
    return updated
  }

  _applyAttrs(span) {
    span.className = "editor-mention"
    span.dataset.mentionUsername = this.__username
    if (this.__external) {
      span.dataset.external = "true"
    } else {
      delete span.dataset.external
    }
    if (this.__mtasksUserId != null) {
      span.dataset.mtasksUserId = String(this.__mtasksUserId)
    } else {
      delete span.dataset.mtasksUserId
    }
  }

  exportJSON() {
    return {
      ...super.exportJSON(),
      type: "mention",
      username: this.__username,
      external: this.__external,
      mtasksUserId: this.__mtasksUserId
    }
  }

  static importJSON(json) {
    return $createMentionNode(json.username, {
      external: json.external,
      mtasksUserId: json.mtasksUserId
    })
  }

  static importDOM() {
    return {
      span: (domNode) => {
        if (domNode.classList.contains("editor-mention") && domNode.dataset.mentionUsername) {
          return {
            conversion: (element) => {
              const username = element.dataset.mentionUsername
              const external = element.dataset.external === "true"
              const rawId = element.dataset.mtasksUserId
              const mtasksUserId = rawId ? Number(rawId) : null
              return { node: $createMentionNode(username, { external, mtasksUserId }) }
            },
            priority: 1
          }
        }
        return null
      }
    }
  }

  isTextEntity() {
    return true
  }

  canInsertTextBefore() {
    return false
  }

  canInsertTextAfter() {
    return false
  }
}

export function $createMentionNode(username, options = {}) {
  const { external = false, mtasksUserId = null } = options
  const node = new MentionNode(username, external, mtasksUserId, `@${username}`)
  node.setMode("token")
  return node
}

export function $isMentionNode(node) {
  return node instanceof MentionNode
}
