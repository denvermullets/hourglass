import { Controller } from "@hotwired/stimulus"

// Plain-textarea message composer. Replaces the Lexical-based
// message_composer_controller with lightweight textarea behaviors:
// enter-to-send, auto-grow, resize presets, markdown toolbar wrappers,
// and quote-reply. No Lexical/prism imports.
export default class extends Controller {
  static targets = ["textarea", "resizeBtn"]
  // serverId / channelId / channelLinked are consumed by the typeahead
  // features added in a later issue; declared here so they survive on connect.
  static values = {
    serverId: String,
    channelId: String,
    channelLinked: Boolean,
  }

  connect() {
    this._onKeydown = this._handleKeydown.bind(this)
    this._onInput = this._autoGrow.bind(this)
    this._onQuote = (e) => this._insertQuote(e.detail || {})

    this.textareaTarget.addEventListener("keydown", this._onKeydown)
    this.textareaTarget.addEventListener("input", this._onInput)
    document.addEventListener("message:quote", this._onQuote)

    // Fit any pre-filled content (e.g. the edit form) on load.
    this._autoGrow()
  }

  disconnect() {
    this.textareaTarget.removeEventListener("keydown", this._onKeydown)
    this.textareaTarget.removeEventListener("input", this._onInput)
    document.removeEventListener("message:quote", this._onQuote)
  }

  // Actions

  // Prevent toolbar buttons from stealing focus / clearing the textarea
  // selection when clicked (mousedown fires before the click handler runs).
  preventFocusLoss(event) {
    event.preventDefault()
  }

  bold(event) {
    event.preventDefault()
    this._wrapSelection("**", "**")
  }

  italic(event) {
    event.preventDefault()
    this._wrapSelection("*", "*")
  }

  strikethrough(event) {
    event.preventDefault()
    this._wrapSelection("~~", "~~")
  }

  code(event) {
    event.preventDefault()
    this._wrapSelection("`", "`")
  }

  codeBlock(event) {
    event.preventDefault()
    this._wrapSelection("```\n", "\n```")
  }

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

  // Clear the textarea after a successful submit (turbo:submit-end).
  reset() {
    this.textareaTarget.value = ""
    this._applyEditorSize("default")
    this._autoGrow()
    this.textareaTarget.focus()
  }

  // Private

  _handleKeydown(event) {
    if (event.key !== "Enter" || event.shiftKey) return
    // On touch devices Enter inserts a newline; sending is done via the
    // send button, so leave the default behavior alone.
    if (this._isTouchDevice()) return

    event.preventDefault()
    this.element.requestSubmit()
  }

  _autoGrow() {
    const ta = this.textareaTarget
    ta.style.height = "auto"
    // scrollHeight is the full content height; CSS max-height clamps the
    // rendered box and overflow-y:auto handles the scroll past that.
    ta.style.height = `${ta.scrollHeight}px`
  }

  _wrapSelection(before, after) {
    const ta = this.textareaTarget
    const { selectionStart: start, selectionEnd: end, value } = ta
    const selected = value.slice(start, end)

    ta.value = value.slice(0, start) + before + selected + after + value.slice(end)

    // Re-select the wrapped text (or drop the cursor between the markers
    // when nothing was selected) so the user can keep typing.
    ta.selectionStart = start + before.length
    ta.selectionEnd = start + before.length + selected.length

    this._autoGrow()
    ta.focus()
  }

  _applyEditorSize(size) {
    const ta = this.textareaTarget

    if (size === "default") {
      ta.style.maxHeight = "12.5rem"
      ta.style.minHeight = "2.25rem"
    } else if (size === "half") {
      ta.style.maxHeight = "50vh"
      ta.style.minHeight = "50vh"
    } else if (size === "full") {
      const messageArea = this.element.closest(".flex-1.flex.flex-col.min-h-0.overflow-hidden")
      const areaHeight = messageArea ? messageArea.clientHeight : window.innerHeight - 100
      const height = `${Math.max(200, areaHeight - 60)}px`
      ta.style.maxHeight = height
      ta.style.minHeight = height
    }

    this.resizeBtnTargets.forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.size === size)
    })

    this._autoGrow()
    ta.focus()
  }

  // Prepend a markdown quote of the given plain-text body to the textarea.
  _insertQuote({ body }) {
    if (!body) return

    const ta = this.textareaTarget
    ta.value = `> ${body}\n\n${ta.value}`

    // Place the cursor after the quote block, ready to type a reply.
    const caret = `> ${body}\n\n`.length
    ta.selectionStart = caret
    ta.selectionEnd = caret

    this._autoGrow()
    ta.focus()
  }

  _isTouchDevice() {
    return (
      typeof window !== "undefined" &&
      typeof window.matchMedia === "function" &&
      window.matchMedia("(pointer: coarse)").matches
    )
  }
}
