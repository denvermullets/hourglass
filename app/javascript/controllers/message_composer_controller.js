import { Controller } from "@hotwired/stimulus"
import { MentionNode, $createMentionNode } from "lexical/mention_node"
import { ChannelNode, $createChannelNode } from "lexical/channel_node"

export default class extends Controller {
  static targets = ["editor", "hiddenInput", "placeholder", "resizeBtn"]
  static values = { placeholder: String, content: String, serverId: String }

  async connect() {
    this._ready = false

    // Prism must be on window before @lexical/code loads
    const Prism = await import("prismjs")
    window.Prism = Prism.default || Prism

    const [
      lexical,
      richText,
      markdown,
      code,
      link,
      list,
      html
    ] = await Promise.all([
      import("lexical"),
      import("@lexical/rich-text"),
      import("@lexical/markdown"),
      import("@lexical/code"),
      import("@lexical/link"),
      import("@lexical/list"),
      import("@lexical/html")
    ])

    // Bail out if disconnected while awaiting imports
    if (this.isDisconnecting) return

    this.lexical = lexical
    this.htmlModule = html

    const {
      createEditor, $getSelection, $isRangeSelection,
      KEY_ENTER_COMMAND, COMMAND_PRIORITY_HIGH
    } = lexical

    const { registerRichText, HeadingNode, QuoteNode } = richText
    const { TRANSFORMERS, $convertFromMarkdownString } = markdown
    this._TRANSFORMERS = TRANSFORMERS
    this._$convertFromMarkdownString = $convertFromMarkdownString
    const { CodeNode, CodeHighlightNode, $createCodeNode, $isCodeNode, registerCodeHighlighting } = code
    const { LinkNode, AutoLinkNode, $createAutoLinkNode, $isAutoLinkNode, $isLinkNode } = link
    const { ListNode, ListItemNode } = list

    // Store for use in auto-link and codeBlock action
    this._$createAutoLinkNode = $createAutoLinkNode
    this._$isAutoLinkNode = $isAutoLinkNode
    this._$isLinkNode = $isLinkNode
    this._createCodeNode = $createCodeNode
    this._isCodeNode = $isCodeNode
    this._CodeNode = CodeNode

    this.editor = createEditor({
      namespace: "MessageComposer",
      theme: {
        text: {
          bold: "editor-bold",
          italic: "editor-italic",
          strikethrough: "editor-strikethrough",
          code: "editor-code",
          underline: "editor-underline"
        },
        link: "editor-link",
        code: "editor-code-block",
        heading: {
          h1: "editor-heading-h1",
          h2: "editor-heading-h2",
          h3: "editor-heading-h3"
        }
      },
      nodes: [
        HeadingNode,
        QuoteNode,
        CodeNode,
        CodeHighlightNode,
        LinkNode,
        AutoLinkNode,
        ListNode,
        ListItemNode,
        MentionNode,
        ChannelNode
      ],
      onError: (error) => console.error("Lexical error:", error)
    })

    this._editorNodes = [
      HeadingNode, QuoteNode, CodeNode, CodeHighlightNode,
      LinkNode, AutoLinkNode, ListNode, ListItemNode,
      MentionNode, ChannelNode
    ]

    this.editor.setRootElement(this.editorTarget)
    registerRichText(this.editor)
    registerCodeHighlighting(this.editor)
    this._registerAutoLink(lexical)

    // Pre-populate editor with existing HTML content (used for editing messages)
    if (this.hasContentValue && this.contentValue) {
      // Convert tables and HRs back to markdown so they're editable
      // and will re-convert on send
      let editableHtml = this._tablesToMarkdown(this.contentValue)
      editableHtml = editableHtml.replace(/<hr\s*\/?>/g, "<p>---</p>")
      this.editor.update(() => {
        const parser = new DOMParser()
        const dom = parser.parseFromString(editableHtml, "text/html")
        const nodes = this.htmlModule.$generateNodesFromDOM(this.editor, dom)
        const root = this.lexical.$getRoot()
        root.clear()
        nodes.forEach(node => root.append(node))
      })
    }

    this._cleanups = []

    // Enter to send, Shift+Enter for newline
    this._cleanups.push(
      this.editor.registerCommand(
        KEY_ENTER_COMMAND,
        (event) => {
          // If mention or channel dropdown is open, select the active item
          if (this._mentionDropdown) {
            event?.preventDefault()
            this._selectActiveMention()
            return true
          }
          if (this._channelDropdown) {
            event?.preventDefault()
            this._selectActiveChannel()
            return true
          }
          if (event && !event.shiftKey) {
            event.preventDefault()
            this._submitMessage()
            return true
          }
          return false
        },
        COMMAND_PRIORITY_HIGH
      )
    )

    // Ensure code blocks are never the last node — append an empty paragraph
    // so the cursor always has somewhere to go after a code block
    this._cleanups.push(
      this.editor.registerUpdateListener(() => {
        this.editor.update(() => {
          const root = this.lexical.$getRoot()
          const lastChild = root.getLastChild()
          if (lastChild && this._isCodeNode(lastChild)) {
            root.append(this.lexical.$createParagraphNode())
          }
        }, { tag: "history-merge" })
      })
    )

    // Track active formats for toolbar button states, code block language picker, and mentions
    this._cleanups.push(
      this.editor.registerUpdateListener(({ editorState }) => {
        editorState.read(() => {
          const selection = $getSelection()
          if ($isRangeSelection(selection)) {
            this._updateToolbarState(selection)
            this._updateLanguagePicker(selection)
            this._checkMentionTrigger(selection)
            this._checkChannelTrigger(selection)
          }
          this._updatePlaceholder()
        })
      })
    )

    // Intercept arrow keys, Tab, and Escape for mention dropdown navigation
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_ARROW_DOWN_COMMAND,
        (event) => this._handleMentionNav(event, "down") || this._handleChannelNav(event, "down"),
        lexical.COMMAND_PRIORITY_HIGH
      )
    )
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_ARROW_UP_COMMAND,
        (event) => this._handleMentionNav(event, "up") || this._handleChannelNav(event, "up"),
        lexical.COMMAND_PRIORITY_HIGH
      )
    )
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_TAB_COMMAND,
        (event) => {
          if (this._mentionDropdown) {
            event.preventDefault()
            this._selectActiveMention()
            return true
          }
          if (this._channelDropdown) {
            event.preventDefault()
            this._selectActiveChannel()
            return true
          }
          return false
        },
        lexical.COMMAND_PRIORITY_HIGH
      )
    )
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_ESCAPE_COMMAND,
        () => {
          if (this._mentionDropdown) {
            this._hideMentionDropdown()
            return true
          }
          if (this._channelDropdown) {
            this._hideChannelDropdown()
            return true
          }
          return false
        },
        lexical.COMMAND_PRIORITY_HIGH
      )
    )

    // Listen for quote events
    this._handleQuote = (e) => this._insertQuote(e.detail)
    document.addEventListener("message:quote", this._handleQuote)

    this._ready = true
    this._submitting = false
    this._updatePlaceholder()
    this.editorTarget.focus()
  }

  disconnect() {
    this.isDisconnecting = true
    this._removeLanguagePicker()
    this._hideMentionDropdown()
    this._hideChannelDropdown()

    if (this._handleQuote) {
      document.removeEventListener("message:quote", this._handleQuote)
      this._handleQuote = null
    }
    if (this._autoLinkCleanup) {
      this._autoLinkCleanup()
      this._autoLinkCleanup = null
    }
    if (this._cleanups) {
      this._cleanups.forEach(cleanup => cleanup())
      this._cleanups = null
    }
    if (this.editor) {
      this.editor.setRootElement(null)
      this.editor = null
    }

    this._ready = false
  }

  // Prevent toolbar buttons from stealing focus from the editor
  preventFocusLoss(event) {
    event.preventDefault()
  }

  // Toolbar actions
  bold(event) {
    event.preventDefault()
    if (!this._ready) return
    this.editor.dispatchCommand(this.lexical.FORMAT_TEXT_COMMAND, "bold")
  }

  italic(event) {
    event.preventDefault()
    if (!this._ready) return
    this.editor.dispatchCommand(this.lexical.FORMAT_TEXT_COMMAND, "italic")
  }

  strikethrough(event) {
    event.preventDefault()
    if (!this._ready) return
    this.editor.dispatchCommand(this.lexical.FORMAT_TEXT_COMMAND, "strikethrough")
  }

  code(event) {
    event.preventDefault()
    if (!this._ready) return
    this.editor.dispatchCommand(this.lexical.FORMAT_TEXT_COMMAND, "code")
  }

  codeBlock(event) {
    event.preventDefault()
    if (!this._ready) return

    const { $getSelection, $isRangeSelection, $createTextNode } = this.lexical
    const $createCodeNode = this._createCodeNode

    this.editor.update(() => {
      const selection = $getSelection()
      if (!$isRangeSelection(selection)) return

      const anchorNode = selection.anchor.getNode()
      const topLevelNode = anchorNode.getTopLevelElement()
      if (!topLevelNode) return

      const codeNode = $createCodeNode()
      // Add an empty text node so the cursor has somewhere to land
      const textNode = $createTextNode("")
      codeNode.append(textNode)

      if (topLevelNode.getTextContent().trim() === "") {
        topLevelNode.replace(codeNode)
      } else {
        topLevelNode.insertAfter(codeNode)
      }
      textNode.select()
    })
  }

  // Editor resize actions
  resizeDefault(event) {
    event.preventDefault()
    this._applyEditorSize("default")
  }

  resizeHalf(event) {
    event.preventDefault()
    this._applyEditorSize("half")
  }

  resizeFull(event) {
    event.preventDefault()
    this._applyEditorSize("full")
  }

  _applyEditorSize(size) {
    const editor = this.editorTarget

    if (size === "default") {
      editor.style.maxHeight = "200px"
      editor.style.minHeight = "36px"
    } else if (size === "half") {
      editor.style.maxHeight = "50vh"
      editor.style.minHeight = "50vh"
    } else if (size === "full") {
      const messageArea = this.element.closest(".flex-1.flex.flex-col.min-h-0.overflow-hidden")
      const areaHeight = messageArea ? messageArea.clientHeight : window.innerHeight - 100
      // Subtract the form's own chrome: toolbar, padding, border, thread label etc.
      const height = `${Math.max(200, areaHeight - 60)}px`
      editor.style.maxHeight = height
      editor.style.minHeight = height
    }

    this.resizeBtnTargets.forEach(btn => {
      btn.classList.toggle("active", btn.dataset.size === size)
    })

    this.editorTarget.focus()
  }

  // Reset after successful form submission
  reset() {
    this._setSubmitDisabled(false)
    if (this._submitTimeout) {
      clearTimeout(this._submitTimeout)
      this._submitTimeout = null
    }

    if (!this._ready) return

    this.editor.update(() => {
      const root = this.lexical.$getRoot()
      root.clear()
      root.append(this.lexical.$createParagraphNode())
    })

    this._applyEditorSize("default")
    this.editorTarget.focus()
  }

  // Private

  _registerAutoLink(lexical) {
    const URL_REGEX = /(?<![=\w])https?:\/\/[^\s<>)"']+/g
    const { $isTextNode, $createTextNode, TextNode } = lexical

    this._autoLinkCleanup = this.editor.registerNodeTransform(TextNode, (textNode) => {
      if (!$isTextNode(textNode)) return

      const parent = textNode.getParent()
      if (this._$isAutoLinkNode(parent) || this._$isLinkNode(parent)) return

      const text = textNode.getTextContent()
      const match = URL_REGEX.exec(text)
      URL_REGEX.lastIndex = 0
      if (!match) return

      const url = match[0]
      const start = match.index
      const end = start + url.length

      let targetNode = textNode
      if (start > 0) {
        targetNode = textNode.splitText(start)[1]
      }
      if (end < text.length) {
        targetNode.splitText(url.length)
      }

      const linkNode = this._$createAutoLinkNode(url, { rel: "noopener noreferrer", target: "_blank" })
      const linkText = $createTextNode(url)
      linkNode.append(linkText)
      targetNode.replace(linkNode)
    })
  }

  handleSubmit(event) {
    const html = this._serializeToHtml()
    const hasFiles = this.element.querySelectorAll('input[name="message[files][]"]').length > 0
    if (this._isEmpty(html) && !hasFiles) {
      event.preventDefault()
      return
    }
    this.hiddenInputTarget.value = html
    this._setSubmitDisabled(true)

    // Safety: re-enable after 3s in case turbo:submit-end doesn't fire
    this._submitTimeout = setTimeout(() => {
      this._setSubmitDisabled(false)
    }, 3000)
  }

  _submitMessage() {
    const html = this._serializeToHtml()
    const hasFiles = this.element.querySelectorAll('input[name="message[files][]"]').length > 0
    if (this._isEmpty(html) && !hasFiles) return

    this.hiddenInputTarget.value = html
    this.element.requestSubmit()
  }

  _serializeToHtml() {
    // Check for raw markdown and convert using a temp editor to get clean HTML,
    // without mutating the main editor state.
    let plainText = ""
    this.editor.getEditorState().read(() => {
      plainText = this.lexical.$getRoot().getTextContent()
    })

    if (plainText && this._looksLikeMarkdown(plainText)) {
      const normalized = plainText
        .replace(/\n{3,}/g, "\n\n")
        // Flatten nested blockquotes (>> or > > >) to single >
        .replace(/^(?:>\s*){2,}/gm, "> ")
      const tempEditor = this.lexical.createEditor({
        namespace: "MarkdownTemp",
        nodes: this._editorNodes
      })
      const tempEl = document.createElement("div")
      tempEditor.setRootElement(tempEl)
      tempEditor.update(() => {
        this._$convertFromMarkdownString(normalized, this._TRANSFORMERS)
      }, { discrete: true })

      let html = ""
      tempEditor.getEditorState().read(() => {
        html = this.htmlModule.$generateHtmlFromNodes(tempEditor)
      })
      tempEditor.setRootElement(null)
      return this._cleanHtml(html)
    }

    let html = ""
    this.editor.getEditorState().read(() => {
      html = this.htmlModule.$generateHtmlFromNodes(this.editor)
    })
    return this._cleanHtml(html)
  }

  _cleanHtml(html) {
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
    html = this._convertMarkdownTables(html)
    return html
  }

  _convertMarkdownTables(html) {
    // First, split <p> tags that contain <br> followed by pipe content
    // into separate chunks so table rows aren't merged with preceding text.
    html = html.replace(/(<p[^>]*>)([\s\S]*?)<\/p>/g, (_match, openTag, inner) => {
      // Split on <br> boundaries
      const segments = inner.split(/<br\s*\/?>/)
      if (segments.length <= 1) return _match

      const parts = []
      let current = []
      for (const seg of segments) {
        const text = seg.replace(/<[^>]*>/g, "").trim()
        if (text.startsWith("|") && text.endsWith("|") && current.length > 0) {
          // Previous non-table content becomes its own <p>
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
        result += this._buildTableHtml(tableRows)
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

  _buildTableHtml(lines) {
    // lines[0] = header, lines[1] = separator, lines[2+] = data
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

  _isEmpty(html) {
    if (!html) return true
    const stripped = html.replace(/<[^>]*>/g, "").trim()
    return stripped.length === 0
  }

  _updateToolbarState(selection) {
    const formatButtons = {
      bold: this.element.querySelector('[data-format="bold"]'),
      italic: this.element.querySelector('[data-format="italic"]'),
      strikethrough: this.element.querySelector('[data-format="strikethrough"]'),
      code: this.element.querySelector('[data-format="code"]')
    }

    for (const [format, button] of Object.entries(formatButtons)) {
      if (!button) continue
      if (selection.hasFormat(format)) {
        button.classList.add("active")
      } else {
        button.classList.remove("active")
      }
    }
  }

  _updateLanguagePicker(selection) {
    const anchorNode = selection.anchor.getNode()
    // Walk up the tree to find a CodeNode ancestor
    let codeNode = null
    let node = anchorNode
    while (node) {
      if (this._isCodeNode(node)) {
        codeNode = node
        break
      }
      node = node.getParent()
    }

    if (!codeNode) {
      this._removeLanguagePicker()
      return
    }

    const codeNodeKey = codeNode.getKey()
    // Don't rebuild if already showing for this node
    if (this._langPickerNodeKey === codeNodeKey) return

    this._removeLanguagePicker()
    this._langPickerNodeKey = codeNodeKey

    const codeDomElement = this.editor.getElementByKey(codeNodeKey)
    if (!codeDomElement) return

    // Place picker in the editor's relative parent, positioned over the code block
    const editorWrapper = this.editorTarget.parentElement
    const wrapperRect = editorWrapper.getBoundingClientRect()
    const codeRect = codeDomElement.getBoundingClientRect()

    const picker = document.createElement("select")
    picker.className = "code-lang-picker"
    picker.innerHTML = this._languageOptions(codeNode.getLanguage())
    picker.style.top = `${codeRect.top - wrapperRect.top + 4}px`
    picker.style.right = "4px"

    picker.addEventListener("mousedown", (e) => {
      e.stopPropagation()
    })
    picker.addEventListener("change", (e) => {
      const lang = e.target.value
      this.editor.update(() => {
        const node = this.lexical.$getNodeByKey(codeNodeKey)
        if (node && this._isCodeNode(node)) {
          node.setLanguage(lang || null)
        }
      })
    })

    editorWrapper.appendChild(picker)
    this._langPicker = picker
  }

  _removeLanguagePicker() {
    if (this._langPicker) {
      this._langPicker.remove()
      this._langPicker = null
      this._langPickerNodeKey = null
    }
  }

  _languageOptions(current) {
    const langs = [
      ["", "auto"],
      ["javascript", "js"],
      ["typescript", "ts"],
      ["ruby", "ruby"],
      ["python", "python"],
      ["html", "html"],
      ["css", "css"],
      ["json", "json"],
      ["sql", "sql"],
      ["bash", "bash"],
      ["go", "go"],
      ["rust", "rust"],
      ["java", "java"],
      ["c", "c"],
      ["cpp", "c++"],
      ["yaml", "yaml"],
      ["markdown", "md"],
      ["xml", "xml"],
      ["plaintext", "plain"]
    ]
    return langs.map(([value, label]) => {
      const selected = value === (current || "") ? " selected" : ""
      return `<option value="${value}"${selected}>${label}</option>`
    }).join("")
  }

  _setSubmitDisabled(disabled) {
    const btn = this.element.querySelector('input[type="submit"]')
    if (btn) {
      btn.disabled = disabled
      btn.style.opacity = disabled ? "0.4" : ""
    }
  }

  _insertQuote({ body }) {
    if (!this._ready || !body) return

    // Build a blockquote HTML string and parse it into Lexical nodes
    // using the same DOM-to-Lexical approach used for editing pre-population
    const escaped = body.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const quoteHtml = `<blockquote><p>${escaped}</p></blockquote><p></p>`

    this.editor.update(() => {
      const parser = new DOMParser()
      const dom = parser.parseFromString(quoteHtml, "text/html")
      const nodes = this.htmlModule.$generateNodesFromDOM(this.editor, dom)

      const root = this.lexical.$getRoot()
      const firstChild = root.getFirstChild()
      const isEmpty = root.getChildrenSize() === 1 &&
        firstChild?.getTextContent().trim() === ""

      if (isEmpty) {
        root.clear()
      }

      nodes.forEach(node => root.append(node))

      // Place cursor in the trailing paragraph
      const lastChild = root.getLastChild()
      if (lastChild) lastChild.select()
    })

    this.editorTarget.focus()
  }

  _updatePlaceholder() {
    if (!this.hasPlaceholderTarget || !this.editor) return

    this.editor.getEditorState().read(() => {
      const root = this.lexical.$getRoot()
      const textContent = root.getTextContent()
      this.placeholderTarget.style.display = textContent.length === 0 ? "" : "none"
    })
  }

  // --- @Mention autocomplete ---

  _checkMentionTrigger(selection) {
    if (!selection.isCollapsed()) {
      this._hideMentionDropdown()
      return
    }

    const anchor = selection.anchor
    const node = anchor.getNode()
    const textContent = node.getTextContent()
    const offset = anchor.offset

    // Look backwards from cursor for @ trigger
    const textBeforeCursor = textContent.substring(0, offset)
    const match = textBeforeCursor.match(/@(\w{0,20})$/)

    if (!match) {
      this._hideMentionDropdown()
      return
    }

    const query = match[1]
    this._mentionQuery = query
    this._mentionNodeKey = node.getKey()
    this._mentionOffset = offset

    // Get cursor position for dropdown placement
    const nativeSelection = window.getSelection()
    if (!nativeSelection || nativeSelection.rangeCount === 0) return

    const range = nativeSelection.getRangeAt(0)
    const rect = range.getBoundingClientRect()

    if (query.length >= 1) {
      this._fetchMembers(query).then(members => {
        if (members.length > 0) {
          this._showMentionDropdown(members, rect)
        } else {
          this._hideMentionDropdown()
        }
      })
    } else {
      // Show all members when just "@" is typed
      this._fetchMembers("").then(members => {
        if (members.length > 0) {
          this._showMentionDropdown(members, rect)
        }
      })
    }
  }

  _showMentionDropdown(members, anchorRect) {
    this._hideMentionDropdown()

    const dropdown = document.createElement("div")
    dropdown.className = "mention-autocomplete"
    this._mentionActiveIndex = 0

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

      item.addEventListener("mousedown", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this._insertMention(member.username)
      })

      item.addEventListener("mouseenter", () => {
        this._setActiveIndex(index)
      })

      dropdown.appendChild(item)
    })

    this._mentionMembers = members

    // Position fixed on document.body to avoid overflow-hidden clipping
    dropdown.style.position = "fixed"
    dropdown.style.left = `${anchorRect.left}px`
    dropdown.style.bottom = `${window.innerHeight - anchorRect.top + 4}px`

    document.body.appendChild(dropdown)
    this._mentionDropdown = dropdown
  }

  _hideMentionDropdown() {
    if (this._mentionDropdown) {
      this._mentionDropdown.remove()
      this._mentionDropdown = null
      this._mentionMembers = null
      this._mentionActiveIndex = 0
    }
  }

  _handleMentionNav(event, direction) {
    if (!this._mentionDropdown || !this._mentionMembers) return false

    event.preventDefault()
    const items = this._mentionDropdown.querySelectorAll(".mention-autocomplete-item")
    const max = items.length - 1

    if (direction === "down") {
      this._setActiveIndex(Math.min(this._mentionActiveIndex + 1, max))
    } else {
      this._setActiveIndex(Math.max(this._mentionActiveIndex - 1, 0))
    }

    return true
  }

  _setActiveIndex(index) {
    const items = this._mentionDropdown?.querySelectorAll(".mention-autocomplete-item")
    if (!items) return

    items.forEach((item, i) => {
      item.classList.toggle("active", i === index)
    })
    this._mentionActiveIndex = index

    // Scroll active item into view
    items[index]?.scrollIntoView({ block: "nearest" })
  }

  _selectActiveMention() {
    if (!this._mentionMembers || this._mentionActiveIndex == null) return
    const member = this._mentionMembers[this._mentionActiveIndex]
    if (member) {
      this._insertMention(member.username)
    }
  }

  _insertMention(username) {
    this._hideMentionDropdown()

    const nodeKey = this._mentionNodeKey
    const offset = this._mentionOffset
    const query = this._mentionQuery

    this.editor.update(() => {
      const node = this.lexical.$getNodeByKey(nodeKey)
      if (!node) return

      const textContent = node.getTextContent()
      // Find the @ trigger position
      const triggerStart = offset - query.length - 1 // -1 for the @

      // Split the text node and insert mention
      const mentionNode = $createMentionNode(username)
      const spaceNode = this.lexical.$createTextNode(" ")

      if (triggerStart === 0 && offset === textContent.length) {
        // The entire node is the @query
        node.replace(mentionNode)
        mentionNode.insertAfter(spaceNode)
      } else if (triggerStart === 0) {
        // @ is at start of node
        const remaining = node.getTextContent().substring(offset)
        node.setTextContent(remaining)
        node.insertBefore(mentionNode)
        mentionNode.insertAfter(spaceNode)
      } else {
        // @ is in middle of text
        const before = textContent.substring(0, triggerStart)
        const after = textContent.substring(offset)
        node.setTextContent(before)
        node.insertAfter(spaceNode)
        node.insertAfter(mentionNode)
        if (after) {
          const afterNode = this.lexical.$createTextNode(after)
          spaceNode.insertAfter(afterNode)
        }
      }

      spaceNode.select()
    })
  }

  async _fetchMembers(query) {
    if (!this.hasServerIdValue || !this.serverIdValue) return []

    try {
      const url = `/servers/${this.serverIdValue}/members?q=${encodeURIComponent(query)}`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) return []
      return await response.json()
    } catch {
      return []
    }
  }

  // --- #Channel autocomplete ---

  _checkChannelTrigger(selection) {
    if (!selection.isCollapsed()) {
      this._hideChannelDropdown()
      return
    }

    const anchor = selection.anchor
    const node = anchor.getNode()
    const textContent = node.getTextContent()
    const offset = anchor.offset

    const textBeforeCursor = textContent.substring(0, offset)
    const match = textBeforeCursor.match(/#([a-z0-9-]{0,30})$/)

    if (!match) {
      this._hideChannelDropdown()
      return
    }

    const query = match[1]
    this._channelQuery = query
    this._channelNodeKey = node.getKey()
    this._channelOffset = offset

    const nativeSelection = window.getSelection()
    if (!nativeSelection || nativeSelection.rangeCount === 0) return

    const range = nativeSelection.getRangeAt(0)
    const rect = range.getBoundingClientRect()

    this._fetchChannels(query).then(channels => {
      if (channels.length > 0) {
        this._showChannelDropdown(channels, rect)
      } else {
        this._hideChannelDropdown()
      }
    })
  }

  _showChannelDropdown(channels, anchorRect) {
    this._hideChannelDropdown()

    const dropdown = document.createElement("div")
    dropdown.className = "mention-autocomplete"
    this._channelActiveIndex = 0

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
        this._setChannelActiveIndex(index)
      })

      dropdown.appendChild(item)
    })

    this._channelItems = channels

    dropdown.style.position = "fixed"
    dropdown.style.left = `${anchorRect.left}px`
    dropdown.style.bottom = `${window.innerHeight - anchorRect.top + 4}px`

    document.body.appendChild(dropdown)
    this._channelDropdown = dropdown
  }

  _hideChannelDropdown() {
    if (this._channelDropdown) {
      this._channelDropdown.remove()
      this._channelDropdown = null
      this._channelItems = null
      this._channelActiveIndex = 0
    }
  }

  _handleChannelNav(event, direction) {
    if (!this._channelDropdown || !this._channelItems) return false

    event.preventDefault()
    const items = this._channelDropdown.querySelectorAll(".mention-autocomplete-item")
    const max = items.length - 1

    if (direction === "down") {
      this._setChannelActiveIndex(Math.min(this._channelActiveIndex + 1, max))
    } else {
      this._setChannelActiveIndex(Math.max(this._channelActiveIndex - 1, 0))
    }

    return true
  }

  _setChannelActiveIndex(index) {
    const items = this._channelDropdown?.querySelectorAll(".mention-autocomplete-item")
    if (!items) return

    items.forEach((item, i) => {
      item.classList.toggle("active", i === index)
    })
    this._channelActiveIndex = index
    items[index]?.scrollIntoView({ block: "nearest" })
  }

  _selectActiveChannel() {
    if (!this._channelItems || this._channelActiveIndex == null) return
    const channel = this._channelItems[this._channelActiveIndex]
    if (channel) {
      this._insertChannel(channel.id, channel.name, channel.server_id)
    }
  }

  _insertChannel(channelId, channelName, serverId) {
    this._hideChannelDropdown()

    const nodeKey = this._channelNodeKey
    const offset = this._channelOffset
    const query = this._channelQuery

    this.editor.update(() => {
      const node = this.lexical.$getNodeByKey(nodeKey)
      if (!node) return

      const textContent = node.getTextContent()
      const triggerStart = offset - query.length - 1 // -1 for the #

      const channelNode = $createChannelNode(channelId, channelName, serverId)
      const spaceNode = this.lexical.$createTextNode(" ")

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
          const afterNode = this.lexical.$createTextNode(after)
          spaceNode.insertAfter(afterNode)
        }
      }

      spaceNode.select()
    })
  }

  _tablesToMarkdown(html) {
    // Convert <table> elements back to markdown pipe syntax for editing
    return html.replace(/<table>[\s\S]*?<\/table>/g, (tableHtml) => {
      const parser = new DOMParser()
      const doc = parser.parseFromString(tableHtml, "text/html")
      const table = doc.querySelector("table")
      if (!table) return tableHtml

      const rows = []
      const headerCells = table.querySelectorAll("thead th")
      if (headerCells.length > 0) {
        rows.push("| " + Array.from(headerCells).map(th => th.textContent.trim()).join(" | ") + " |")
        rows.push("| " + Array.from(headerCells).map(() => "---").join(" | ") + " |")
      }

      table.querySelectorAll("tbody tr").forEach(tr => {
        const cells = tr.querySelectorAll("td")
        rows.push("| " + Array.from(cells).map(td => td.textContent.trim()).join(" | ") + " |")
      })

      return rows.map(row => `<p>${row}</p>`).join("")
    })
  }

  _looksLikeMarkdown(text) {
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

  async _fetchChannels(query) {
    if (!this.hasServerIdValue || !this.serverIdValue) return []

    try {
      const url = `/servers/${this.serverIdValue}/channels/search?q=${encodeURIComponent(query)}`
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) return []
      return await response.json()
    } catch {
      return []
    }
  }
}
