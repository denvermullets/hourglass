export function createSerializer({ createEditor, editorNodes, convertFromMarkdownString, transformers, generateHtmlFromNodes }) {

  function looksLikeMarkdown(text) {
    const patterns = [
      /^#{1,6}\s/m,           // headings
      /\*\*.+?\*\*/,          // bold
      /~~.+?~~/,              // strikethrough
      /^```/m,                // fenced code block
      /^>\s/m,                // blockquote
      /^[-*+]\s/m,            // unordered list
      /^\d+\.\s/m,            // ordered list
      /\[.+?\]\(.+?\)/,       // link
    ]

    for (const pattern of patterns) {
      if (pattern.test(text)) return true
    }
    return false
  }

  function isEmpty(html) {
    if (!html) return true
    const stripped = html.replace(/<[^>]*>/g, "").trim()
    return stripped.length === 0
  }

  function buildTableHtml(lines) {
    const parseRow = (line) =>
      line.split("|").slice(1, -1).map(cell => cell.trim())

    const separator = parseRow(lines[1])
    const alignments = separator.map(cell => {
      if (cell.startsWith(":") && cell.endsWith(":")) return "center"
      if (cell.endsWith(":")) return "right"
      return "left"
    })

    const alignClass = (a) => a === "center" ? ' class="text-center"' : a === "right" ? ' class="text-right"' : ""

    const headerCells = parseRow(lines[0])
    let tableHtml = "<table><thead><tr>"
    headerCells.forEach((cell, i) => {
      tableHtml += `<th${alignClass(alignments[i])}>${cell}</th>`
    })
    tableHtml += "</tr></thead><tbody>"

    for (let r = 2; r < lines.length; r++) {
      const cells = parseRow(lines[r])
      tableHtml += "<tr>"
      cells.forEach((cell, i) => {
        tableHtml += `<td${alignClass(alignments[i])}>${cell}</td>`
      })
      tableHtml += "</tr>"
    }

    tableHtml += "</tbody></table>"
    return tableHtml
  }

  function convertMarkdownTables(html) {
    // First, split <p> tags that contain <br> followed by pipe content
    // into separate chunks so table rows aren't merged with preceding text.
    html = html.replace(/(<p[^>]*>)([\s\S]*?)<\/p>/g, (_match, openTag, inner) => {
      const segments = inner.split(/<br\s*\/?>/)
      if (segments.length <= 1) return _match

      const parts = []
      let current = []
      for (const seg of segments) {
        const text = seg.replace(/<[^>]*>/g, "").trim()
        if (text.startsWith("|") && text.endsWith("|") && current.length > 0) {
          parts.push(`${openTag}${current.join("<br>")}</p>`)
          current = []
        }
        current.push(seg)
      }
      if (current.length > 0) {
        parts.push(`${openTag}${current.join("<br>")}</p>`)
      }
      return parts.join("")
    })

    // Now split into <p> chunks and non-<p> content
    const chunks = []
    const pRegex = /(<p[^>]*>[\s\S]*?<\/p>)/g
    let lastIndex = 0
    let m

    while ((m = pRegex.exec(html)) !== null) {
      if (m.index > lastIndex) {
        chunks.push({ type: "other", raw: html.slice(lastIndex, m.index) })
      }
      const raw = m[1]
      const text = raw.replace(/<[^>]*>/g, "").trim()
      chunks.push({ type: "p", raw, text })
      lastIndex = pRegex.lastIndex
    }
    if (lastIndex < html.length) {
      chunks.push({ type: "other", raw: html.slice(lastIndex) })
    }

    // Walk chunks, collecting consecutive pipe-rows into table groups
    let result = ""
    let tableRows = []
    let tableRawParts = []

    const flushTable = () => {
      if (tableRows.length >= 3 && /^[\s|:-]+$/.test(tableRows[1])) {
        result += buildTableHtml(tableRows)
      } else {
        result += tableRawParts.join("")
      }
      tableRows = []
      tableRawParts = []
    }

    for (const chunk of chunks) {
      if (chunk.type === "p") {
        const t = chunk.text
        if (t.startsWith("|") && t.endsWith("|")) {
          tableRows.push(t)
          tableRawParts.push(chunk.raw)
          continue
        }
      }
      if (tableRows.length > 0) flushTable()
      result += chunk.raw
    }
    if (tableRows.length > 0) flushTable()

    return result
  }

  function renderMarkdownCodeBlocks(html) {
    return html.replace(
      /<pre[^>]*data-(?:highlight-)?language="(?:md|markdown)"[^>]*>([\s\S]*?)<\/pre>/g,
      (_match, content) => {
        const mdText = content
          .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
        const tempEditor = createEditor({
          namespace: "MdRender",
          nodes: editorNodes
        })
        const tempEl = document.createElement("div")
        tempEditor.setRootElement(tempEl)
        tempEditor.update(() => {
          convertFromMarkdownString(mdText, transformers)
        }, { discrete: true })

        let rendered = ""
        tempEditor.getEditorState().read(() => {
          rendered = generateHtmlFromNodes(tempEditor)
        })
        tempEditor.setRootElement(null)

        // Clean the rendered output (strip Lexical's verbose code block formatting)
        rendered = rendered.replace(/<pre([^>]*)>([\s\S]*?)<\/pre>/g, (_m, attrs, inner) => {
          const plain = inner.replace(/<br\s*\/?>/g, "\n").replace(/<[^>]*>/g, "")
          return `<pre${attrs}>${plain}</pre>`
        })
        rendered = rendered.replace(/^(<p(\s[^>]*)?>\s*(<br\s*\/?>)?\s*<\/p>)+/, "")
        rendered = rendered.replace(/(<p(\s[^>]*)?>\s*(<br\s*\/?>)?\s*<\/p>)+$/, "")
        rendered = rendered.replace(/<p[^>]*>\s*(?:<span[^>]*>)?\s*([-_*])\1{2,}\s*(?:<\/span>)?\s*<\/p>/g, "<hr>")
        rendered = convertMarkdownTables(rendered)
        return rendered
      }
    )
  }

  function cleanHtml(html) {
    // Clean up Lexical's verbose code block output
    html = html.replace(/<pre([^>]*)>([\s\S]*?)<\/pre>/g, (_match, attrs, inner) => {
      const plain = inner
        .replace(/<br\s*\/?>/g, "\n")
        .replace(/<[^>]*>/g, "")
      return `<pre${attrs}>${plain}</pre>`
    })
    // Strip leading/trailing empty paragraphs
    html = html.replace(/^(<p(\s[^>]*)?>\s*(<br\s*\/?>)?\s*<\/p>)+/, "")
    html = html.replace(/(<p(\s[^>]*)?>\s*(<br\s*\/?>)?\s*<\/p>)+$/, "")
    // Convert horizontal rules (---, ___, ***) that survived as plain text
    html = html.replace(/<p[^>]*>\s*(?:<span[^>]*>)?\s*([-_*])\1{2,}\s*(?:<\/span>)?\s*<\/p>/g, "<hr>")
    // Convert markdown tables that survived as plain text in <p> tags
    html = convertMarkdownTables(html)
    // Render ```md code blocks as formatted HTML instead of a code block
    html = renderMarkdownCodeBlocks(html)
    return html
  }

  return { cleanHtml, looksLikeMarkdown, isEmpty }
}
