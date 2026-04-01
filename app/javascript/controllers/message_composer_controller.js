import { Controller } from "@hotwired/stimulus"
import { MentionNode, $createMentionNode } from "lexical/mention_node"

export default class extends Controller {
  static targets = ["editor", "hiddenInput", "placeholder"]
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
    const { registerMarkdownShortcuts, TRANSFORMERS } = markdown
    const { CodeNode, CodeHighlightNode, $createCodeNode, $isCodeNode, registerCodeHighlighting } = code
    const { LinkNode, AutoLinkNode } = link
    const { ListNode, ListItemNode } = list

    // Store for use in codeBlock action and language picker
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
        MentionNode
      ],
      onError: (error) => console.error("Lexical error:", error)
    })

    this.editor.setRootElement(this.editorTarget)
    registerRichText(this.editor)
    registerMarkdownShortcuts(this.editor, TRANSFORMERS)
    registerCodeHighlighting(this.editor)

    // Pre-populate editor with existing HTML content (used for editing messages)
    if (this.hasContentValue && this.contentValue) {
      this.editor.update(() => {
        const parser = new DOMParser()
        const dom = parser.parseFromString(this.contentValue, "text/html")
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
          // If mention dropdown is open, select the active mention
          if (this._mentionDropdown) {
            event?.preventDefault()
            this._selectActiveMention()
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

    // Track active formats for toolbar button states, code block language picker, and mentions
    this._cleanups.push(
      this.editor.registerUpdateListener(({ editorState }) => {
        editorState.read(() => {
          const selection = $getSelection()
          if ($isRangeSelection(selection)) {
            this._updateToolbarState(selection)
            this._updateLanguagePicker(selection)
            this._checkMentionTrigger(selection)
          }
          this._updatePlaceholder()
        })
      })
    )

    // Intercept arrow keys, Tab, and Escape for mention dropdown navigation
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_ARROW_DOWN_COMMAND,
        (event) => this._handleMentionNav(event, "down"),
        lexical.COMMAND_PRIORITY_HIGH
      )
    )
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_ARROW_UP_COMMAND,
        (event) => this._handleMentionNav(event, "up"),
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
          return false
        },
        lexical.COMMAND_PRIORITY_HIGH
      )
    )

    this._ready = true
    this._updatePlaceholder()
  }

  disconnect() {
    this.isDisconnecting = true
    this._removeLanguagePicker()
    this._hideMentionDropdown()

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

  // Reset after successful form submission
  reset() {
    if (!this._ready) return

    this.editor.update(() => {
      const root = this.lexical.$getRoot()
      root.clear()
      root.append(this.lexical.$createParagraphNode())
    })

    this.editorTarget.focus()
  }

  // Private

  _submitMessage() {
    const html = this._serializeToHtml()
    const hasFiles = this.element.querySelectorAll('input[name="message[files][]"]').length > 0
    if (this._isEmpty(html) && !hasFiles) return

    this.hiddenInputTarget.value = html
    this.element.requestSubmit()
  }

  _serializeToHtml() {
    let html = ""
    this.editor.getEditorState().read(() => {
      html = this.htmlModule.$generateHtmlFromNodes(this.editor)
    })
    // Clean up Lexical's verbose code block output — it wraps every token
    // in <span style="white-space: pre-wrap;"> which bloats storage.
    // Extract plain text and keep just the <pre> with a language attr.
    return html.replace(/<pre([^>]*)>([\s\S]*?)<\/pre>/g, (_match, attrs, inner) => {
      const plain = inner
        .replace(/<br\s*\/?>/g, "\n")
        .replace(/<[^>]*>/g, "")
      return `<pre${attrs}>${plain}</pre>`
    })
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
}
