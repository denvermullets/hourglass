import { TextNode } from "lexical"

export class ChannelNode extends TextNode {
  __channelId
  __channelName
  __serverId

  static getType() {
    return "channel"
  }

  static clone(node) {
    return new ChannelNode(node.__channelId, node.__channelName, node.__serverId, node.__text, node.__key)
  }

  constructor(channelId, channelName, serverId, text, key) {
    super(text ?? `#${channelName}`, key)
    this.__channelId = channelId
    this.__channelName = channelName
    this.__serverId = serverId
  }

  createDOM(config) {
    const span = super.createDOM(config)
    span.className = "editor-channel"
    span.dataset.channelId = this.__channelId
    span.dataset.channelName = this.__channelName
    span.dataset.serverId = this.__serverId
    return span
  }

  updateDOM(prevNode, dom, config) {
    const updated = super.updateDOM(prevNode, dom, config)
    dom.className = "editor-channel"
    dom.dataset.channelId = this.__channelId
    dom.dataset.channelName = this.__channelName
    dom.dataset.serverId = this.__serverId
    return updated
  }

  exportJSON() {
    return {
      ...super.exportJSON(),
      type: "channel",
      channelId: this.__channelId,
      channelName: this.__channelName,
      serverId: this.__serverId
    }
  }

  static importJSON(json) {
    return $createChannelNode(json.channelId, json.channelName, json.serverId)
  }

  static importDOM() {
    return {
      span: (domNode) => {
        if (domNode.classList.contains("editor-channel") && domNode.dataset.channelId) {
          return {
            conversion: (element) => {
              const channelId = element.dataset.channelId
              const channelName = element.dataset.channelName
              const serverId = element.dataset.serverId
              return { node: $createChannelNode(channelId, channelName, serverId) }
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

export function $createChannelNode(channelId, channelName, serverId) {
  const node = new ChannelNode(channelId, channelName, serverId, `#${channelName}`)
  node.setMode("token")
  return node
}

export function $isChannelNode(node) {
  return node instanceof ChannelNode
}
