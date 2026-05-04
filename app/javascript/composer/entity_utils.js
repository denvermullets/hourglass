import { MentionNode, $createMentionNode } from "lexical/mention_node"
import { ChannelNode, $createChannelNode } from "lexical/channel_node"

export function getTextWithPlaceholders(root, entities) {
  // Mirrors Lexical's getTextContent() but replaces MentionNode/ChannelNode
  // with unique placeholders so they survive markdown conversion.
  const parts = []

  const walkInline = (node) => {
    if (node instanceof MentionNode) {
      const username = node.__username
      const external = node.__external
      const mtasksUserId = node.__mtasksUserId
      const placeholder = `\x00M${entities.length}\x00`
      const attrs = [`class="editor-mention"`, `data-mention-username="${username}"`]
      if (external) attrs.push(`data-external="true"`)
      if (mtasksUserId != null) attrs.push(`data-mtasks-user-id="${mtasksUserId}"`)
      entities.push({
        placeholder,
        html: `<span ${attrs.join(" ")}>@${username}</span>`
      })
      return placeholder
    }
    if (node instanceof ChannelNode) {
      const { __channelId: cid, __channelName: cname, __serverId: sid } = node
      const placeholder = `\x00M${entities.length}\x00`
      entities.push({
        placeholder,
        html: `<span class="editor-channel" data-channel-id="${cid}" data-channel-name="${cname}" data-server-id="${sid}">#${cname}</span>`
      })
      return placeholder
    }
    const children = node.getChildren ? node.getChildren() : null
    if (!children || children.length === 0) {
      return node.getTextContent()
    }
    return children.map(walkInline).join("")
  }

  const topChildren = root.getChildren()
  for (const block of topChildren) {
    const children = block.getChildren ? block.getChildren() : null
    if (!children || children.length === 0) {
      // Empty paragraph — preserve as blank line
      parts.push("")
    } else {
      parts.push(children.map(walkInline).join(""))
    }
  }

  // Join with \n\n to match Lexical's getTextContent() block separator
  return parts.join("\n\n")
}

export function restoreEntityPlaceholders(html, entities) {
  for (const { placeholder, html: entityHtml } of entities) {
    html = html.split(placeholder).join(entityHtml)
  }
  return html
}

export function extractMentions(html) {
  const doc = new DOMParser().parseFromString(html, "text/html")
  const spans = doc.querySelectorAll("span.editor-mention[data-mention-username]")
  const map = new Map()
  spans.forEach(s => {
    const username = s.dataset.mentionUsername
    const external = s.dataset.external === "true"
    const rawId = s.dataset.mtasksUserId
    const mtasksUserId = rawId ? Number(rawId) : null
    map.set(username, { external, mtasksUserId })
  })
  return map
}

export function extractChannels(html) {
  const doc = new DOMParser().parseFromString(html, "text/html")
  const spans = doc.querySelectorAll("span.editor-channel[data-channel-id]")
  const map = new Map()
  spans.forEach(s => {
    map.set(s.dataset.channelName, {
      channelId: s.dataset.channelId,
      channelName: s.dataset.channelName,
      serverId: s.dataset.serverId
    })
  })
  return map
}

export function restoreEntitiesInTree(root, mentions, channels, lexical, CodeNode) {
  const patterns = []
  for (const username of mentions.keys()) {
    patterns.push(`@${username.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`)
  }
  for (const channelName of channels.keys()) {
    patterns.push(`#${channelName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`)
  }
  if (patterns.length === 0) return

  const regex = new RegExp(`(${patterns.join("|")})`, "g")
  const textNodes = []
  const collect = (node) => {
    if (CodeNode && node instanceof CodeNode) return
    if (lexical.$isTextNode(node)) {
      textNodes.push(node)
      return
    }
    if (node.getChildren) {
      for (const child of node.getChildren()) collect(child)
    }
  }
  collect(root)

  for (const textNode of textNodes) {
    const text = textNode.getTextContent()
    regex.lastIndex = 0
    if (!regex.test(text)) continue
    regex.lastIndex = 0

    const newNodes = []
    let lastIndex = 0
    let match
    while ((match = regex.exec(text)) !== null) {
      if (match.index > lastIndex) {
        newNodes.push(lexical.$createTextNode(text.slice(lastIndex, match.index)))
      }
      const token = match[1]
      if (token.startsWith("@")) {
        const username = token.slice(1)
        const meta = mentions.get(username) || {}
        newNodes.push($createMentionNode(username, meta))
      } else {
        const name = token.slice(1)
        const info = channels.get(name)
        newNodes.push($createChannelNode(info.channelId, info.channelName, info.serverId))
      }
      lastIndex = regex.lastIndex
    }
    if (lastIndex < text.length) {
      newNodes.push(lexical.$createTextNode(text.slice(lastIndex)))
    }

    for (const newNode of newNodes) {
      textNode.insertBefore(newNode)
    }
    textNode.remove()
  }
}
