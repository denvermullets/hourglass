export function htmlToMarkdown(html) {
  const doc = new DOMParser().parseFromString(html, "text/html")
  return convertBlock(doc.body).trim()
}

function convertBlock(node) {
  let md = ""
  for (const child of node.childNodes) {
    if (child.nodeType === Node.TEXT_NODE) {
      const text = child.textContent.trim()
      if (text) md += text + "\n\n"
      continue
    }
    if (child.nodeType !== Node.ELEMENT_NODE) continue

    const tag = child.tagName.toLowerCase()
    switch (tag) {
      case "h1": md += `# ${convertInline(child)}\n\n`; break
      case "h2": md += `## ${convertInline(child)}\n\n`; break
      case "h3": md += `### ${convertInline(child)}\n\n`; break
      case "p": md += `${convertInline(child)}\n\n`; break
      case "pre": {
        const lang = child.getAttribute("data-highlight-language") ||
                     child.getAttribute("data-language") || ""
        md += `\`\`\`${lang}\n${child.textContent}\n\`\`\`\n\n`
        break
      }
      case "hr": md += "---\n\n"; break
      case "blockquote": {
        const content = convertBlock(child).trim()
        md += content.split("\n").map(l => `> ${l}`).join("\n") + "\n\n"
        break
      }
      case "ul": md += convertList(child, 0, false) + "\n"; break
      case "ol": md += convertList(child, 0, true) + "\n"; break
      case "table": md += convertTable(child) + "\n\n"; break
      default: md += convertBlock(child); break
    }
  }
  return md
}

function convertInline(node) {
  let text = ""
  for (const child of node.childNodes) {
    if (child.nodeType === Node.TEXT_NODE) {
      text += child.textContent
      continue
    }
    if (child.nodeType !== Node.ELEMENT_NODE) continue

    const tag = child.tagName.toLowerCase()
    switch (tag) {
      case "strong": text += `**${convertInline(child)}**`; break
      case "em": text += `*${convertInline(child)}*`; break
      case "s": text += `~~${convertInline(child)}~~`; break
      case "code": text += `\`${child.textContent}\``; break
      case "a": {
        const href = child.getAttribute("href") || ""
        text += `[${convertInline(child)}](${href})`
        break
      }
      case "br": text += "\n"; break
      default: text += convertInline(child); break
    }
  }
  return text
}

function convertList(listNode, indent, ordered) {
  let md = ""
  let counter = 1
  for (const li of listNode.children) {
    if (li.tagName?.toLowerCase() !== "li") continue

    const prefix = "    ".repeat(indent) + (ordered ? `${counter}. ` : "- ")
    let hasText = false
    let textContent = ""
    let nestedList = null

    for (const child of li.childNodes) {
      if (child.nodeType === Node.TEXT_NODE && child.textContent.trim()) {
        hasText = true
        textContent += child.textContent
      } else if (child.nodeType === Node.ELEMENT_NODE) {
        const childTag = child.tagName.toLowerCase()
        if (childTag === "ul" || childTag === "ol") {
          nestedList = child
        } else {
          hasText = true
          textContent += convertInline(child)
        }
      }
    }

    if (hasText) {
      md += `${prefix}${textContent.trim()}\n`
    }
    if (nestedList) {
      const isOrdered = nestedList.tagName.toLowerCase() === "ol"
      md += convertList(nestedList, indent + 1, isOrdered)
    }
    counter++
  }
  return md
}

function convertTable(table) {
  const rows = []
  const headerCells = table.querySelectorAll("thead th")
  if (headerCells.length > 0) {
    rows.push("| " + Array.from(headerCells).map(th => th.textContent.trim()).join(" | ") + " |")
    rows.push("| " + Array.from(headerCells).map(th => {
      const cls = th.className || ""
      if (cls.includes("text-center")) return ":---:"
      if (cls.includes("text-right")) return "---:"
      return "---"
    }).join(" | ") + " |")
  }
  table.querySelectorAll("tbody tr").forEach(tr => {
    const cells = tr.querySelectorAll("td")
    rows.push("| " + Array.from(cells).map(td => td.textContent.trim()).join(" | ") + " |")
  })
  return rows.join("\n")
}
