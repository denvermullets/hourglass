// Typeahead providers for the plain-textarea composer.
//
// Each provider describes one trigger (@mention, #channel, /slash) as data:
//   enabled        — whether the trigger is active for this composer
//   dropdownClass  — extra class applied to the dropdown container
//   match(text, caret) -> { query, start, end } | null
//                    the token under the caret to replace (start/end are
//                    indices into `text`, covering the trigger char through
//                    the caret), or null when the trigger doesn't apply
//   fetch(query)   -> Promise<items[]>  candidate rows to show
//   itemChildren(item) -> HTMLElement[] content spans for one dropdown row
//   replacement(item)  -> string        plain text spliced in on select
//
// The Lexical-coupled composer/*_autocomplete.js modules are replaced by
// these; they hit the same server endpoints and produce plain markdown text.

function span(text, className) {
  const el = document.createElement("span")
  if (className) el.className = className
  el.textContent = text
  return el
}

async function fetchJson(url) {
  try {
    const response = await fetch(url, { headers: { Accept: "application/json" } })
    if (!response.ok) return []
    return await response.json()
  } catch {
    return []
  }
}

// @mention — /mentions/search?q=&channel_id=
export function mentionProvider({ channelId }) {
  return {
    enabled: true,
    dropdownClass: "",

    match(text, caret) {
      const before = text.slice(0, caret)
      const m = before.match(/@([\w.+\-@]{0,64})$/)
      if (!m) return null
      return { query: m[1], start: caret - m[0].length, end: caret }
    },

    fetch(query) {
      if (!channelId) return Promise.resolve([])
      const url = `/mentions/search?q=${encodeURIComponent(query)}&channel_id=${encodeURIComponent(channelId)}`
      return fetchJson(url)
    },

    itemChildren(member) {
      const children = [span(`@${member.username}`)]
      if (member.display_name && member.display_name !== member.username) {
        children.push(span(member.display_name, "display-name"))
      }
      if (member.external) {
        children.push(span("external", "mention-external-badge"))
      }
      return children
    },

    replacement(member) {
      return `@${member.username} `
    },
  }
}

// #channel — /servers/:serverId/channels/search?q=
export function channelProvider({ serverId }) {
  return {
    enabled: true,
    dropdownClass: "",

    match(text, caret) {
      const before = text.slice(0, caret)
      const m = before.match(/#([a-z0-9-]{0,30})$/)
      if (!m) return null
      return { query: m[1], start: caret - m[0].length, end: caret }
    },

    fetch(query) {
      if (!serverId) return Promise.resolve([])
      const url = `/servers/${serverId}/channels/search?q=${encodeURIComponent(query)}`
      return fetchJson(url)
    },

    itemChildren(channel) {
      const children = [span(`#${channel.name}`)]
      if (channel.description) {
        children.push(span(channel.description, "display-name"))
      }
      return children
    },

    replacement(channel) {
      return `#${channel.name} `
    },
  }
}

const SLASH_COMMANDS = [
  { name: "issue", usage: "/issue [title]", description: "spawn a new issue from this thread" },
  { name: "link", usage: "/link [JAIT-id]", description: "link this thread to an existing issue" },
  { name: "status", usage: "/status [done|progress|backlog]", description: "change linked issue status" },
]

// /slash-command — only on the first line, only when the channel is
// project-linked. Selecting types `/name ` which the server parses on submit.
export function slashProvider({ linked }) {
  return {
    enabled: !!linked,
    dropdownClass: "slash-menu",

    match(text, caret) {
      const firstLine = text.split("\n", 1)[0]
      // Caret must be within the first line and the whole first line must be
      // exactly `/word` (matching the Lexical menu's first-paragraph rule).
      if (caret > firstLine.length) return null
      const m = firstLine.match(/^\/(\w*)$/)
      if (!m) return null
      return { query: m[1], start: 0, end: firstLine.length }
    },

    fetch(query) {
      return Promise.resolve(SLASH_COMMANDS.filter((c) => c.name.startsWith(query)))
    },

    itemChildren(command) {
      return [
        span(command.usage, "slash-menu-usage"),
        span(`— ${command.description}`, "display-name slash-menu-desc"),
      ]
    },

    replacement(command) {
      return `/${command.name} `
    },
  }
}
