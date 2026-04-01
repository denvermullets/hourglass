import { TextNode } from "lexical"

export class MentionNode extends TextNode {
  __username

  static getType() {
    return "mention"
  }

  static clone(node) {
    return new MentionNode(node.__username, node.__text, node.__key)
  }

  constructor(username, text, key) {
    super(text ?? `@${username}`, key)
    this.__username = username
  }

  createDOM(config) {
    const span = super.createDOM(config)
    span.className = "editor-mention"
    span.dataset.mentionUsername = this.__username
    return span
  }

  updateDOM(prevNode, dom, config) {
    const updated = super.updateDOM(prevNode, dom, config)
    dom.className = "editor-mention"
    dom.dataset.mentionUsername = this.__username
    return updated
  }

  exportJSON() {
    return {
      ...super.exportJSON(),
      type: "mention",
      username: this.__username
    }
  }

  static importJSON(json) {
    return $createMentionNode(json.username)
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

export function $createMentionNode(username) {
  const node = new MentionNode(username, `@${username}`)
  node.setMode("token")
  return node
}

export function $isMentionNode(node) {
  return node instanceof MentionNode
}
