import { MentionNode, $createMentionNode } from "lexical/mention_node"
import { ChannelNode, $createChannelNode } from "lexical/channel_node"

export function getTextWithPlaceholders(root, entities) {
  // Mirrors Lexical's getTextContent() but replaces MentionNode/ChannelNode
  // with unique placeholders so they survive markdown conversion.
  const parts = []

  const walkInline = (node) => {
    if (node instanceof MentionNode) {
      const username = node.__username
      const placeholder = `\x00M${entities.length}\x00`
      entities.push({
        placeholder,
        html: `<span class="editor-mention" data-mention-username="${username}">@${username}</span>`
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
  const set = new Set()
  spans.forEach(s => set.add(s.dataset.mentionUsername))
  return set
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

export function appendLineWithMentions(para, line, mentions, channels, $createTextNode) {
  // Build a regex that matches @username for known mentions and #channel for known channels
  const patterns = []
  for (const username of mentions) {
    patterns.push(`@${username.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`)
  }
  for (const channelName of channels.keys()) {
    patterns.push(`#${channelName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`)
  }

  if (patterns.length === 0) {
    para.append($createTextNode(line))
    return
  }

  const regex = new RegExp(`(${patterns.join("|")})`, "g")
  let lastIndex = 0
  let match

  while ((match = regex.exec(line)) !== null) {
    if (match.index > lastIndex) {
      para.append($createTextNode(line.slice(lastIndex, match.index)))
    }
    const token = match[1]
    if (token.startsWith("@")) {
      const username = token.slice(1)
      para.append($createMentionNode(username))
    } else {
      const channelName = token.slice(1)
      const info = channels.get(channelName)
      para.append($createChannelNode(info.channelId, info.channelName, info.serverId))
    }
    lastIndex = regex.lastIndex
  }

  if (lastIndex < line.length) {
    para.append($createTextNode(line.slice(lastIndex)))
  }
}
