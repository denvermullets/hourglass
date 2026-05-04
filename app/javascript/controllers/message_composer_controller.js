import { Controller } from "@hotwired/stimulus";
import { MentionNode } from "lexical/mention_node";
import { ChannelNode } from "lexical/channel_node";
import { htmlToMarkdown } from "composer/html_to_markdown";
import { createSerializer } from "composer/serializer";
import {
  getTextWithPlaceholders,
  restoreEntityPlaceholders,
  extractMentions,
  extractChannels,
  restoreEntitiesInTree,
} from "composer/entity_utils";
import { MentionAutocomplete } from "composer/mention_autocomplete";
import { ChannelAutocomplete } from "composer/channel_autocomplete";
import { SlashMenu } from "composer/slash_menu";

const SLASH_COMMANDS = [
  { name: "issue", usage: "/issue [title]", description: "spawn a new issue from this thread" },
  { name: "link", usage: "/link [JAIT-id]", description: "link this thread to an existing issue" },
  { name: "status", usage: "/status [done|progress|backlog]", description: "change linked issue status" },
];

export default class extends Controller {
  static targets = ["editor", "hiddenInput", "placeholder", "resizeBtn"];
  static values = { placeholder: String, content: String, serverId: String, channelLinked: Boolean };

  async connect() {
    this._ready = false;

    // Prism must be on window before @lexical/code loads
    const Prism = await import("prismjs");
    window.Prism = Prism.default || Prism;

    const [lexical, richText, markdown, code, link, list, html] = await Promise.all([
      import("lexical"),
      import("@lexical/rich-text"),
      import("@lexical/markdown"),
      import("@lexical/code"),
      import("@lexical/link"),
      import("@lexical/list"),
      import("@lexical/html"),
    ]);

    // Bail out if disconnected while awaiting imports
    if (this.isDisconnecting) return;

    this.lexical = lexical;
    this.htmlModule = html;

    const {
      createEditor,
      $getSelection,
      $isRangeSelection,
      KEY_ENTER_COMMAND,
      PASTE_COMMAND,
      COMMAND_PRIORITY_HIGH,
    } = lexical;

    const { registerRichText, HeadingNode, QuoteNode } = richText;
    const { TRANSFORMERS, $convertFromMarkdownString } = markdown;
    this._TRANSFORMERS = TRANSFORMERS;
    this._$convertFromMarkdownString = $convertFromMarkdownString;
    const { CodeNode, CodeHighlightNode, $createCodeNode, $isCodeNode, registerCodeHighlighting } =
      code;
    const { LinkNode, AutoLinkNode, $createAutoLinkNode, $isAutoLinkNode, $isLinkNode } = link;
    const { ListNode, ListItemNode } = list;

    // Store for use in auto-link and codeBlock action
    this._$createAutoLinkNode = $createAutoLinkNode;
    this._$isAutoLinkNode = $isAutoLinkNode;
    this._$isLinkNode = $isLinkNode;
    this._createCodeNode = $createCodeNode;
    this._isCodeNode = $isCodeNode;
    this._CodeNode = CodeNode;

    this.editor = createEditor({
      namespace: "MessageComposer",
      theme: {
        text: {
          bold: "editor-bold",
          italic: "editor-italic",
          strikethrough: "editor-strikethrough",
          code: "editor-code",
          underline: "editor-underline",
        },
        link: "editor-link",
        code: "editor-code-block",
        heading: {
          h1: "editor-heading-h1",
          h2: "editor-heading-h2",
          h3: "editor-heading-h3",
        },
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
        ChannelNode,
      ],
      onError: (error) => console.error("Lexical error:", error),
    });

    this._editorNodes = [
      HeadingNode,
      QuoteNode,
      CodeNode,
      CodeHighlightNode,
      LinkNode,
      AutoLinkNode,
      ListNode,
      ListItemNode,
      MentionNode,
      ChannelNode,
    ];

    this._serializer = createSerializer({
      createEditor: lexical.createEditor,
      editorNodes: this._editorNodes,
      convertFromMarkdownString: $convertFromMarkdownString,
      transformers: TRANSFORMERS,
      generateHtmlFromNodes: html.$generateHtmlFromNodes,
    });

    this.editor.setRootElement(this.editorTarget);
    registerRichText(this.editor);
    registerCodeHighlighting(this.editor);
    this._registerAutoLink(lexical);

    // Pre-populate editor with existing HTML content (used for editing messages)
    // Convert HTML to markdown then parse with Lexical's markdown parser so
    // round-trips are stable (manual paragraph splitting accumulates blank
    // lines on each edit). Mention/channel spans render as @username/#name in
    // the markdown text and are restored as proper nodes after parsing.
    if (this.hasContentValue && this.contentValue) {
      const mentions = extractMentions(this.contentValue);
      const channels = extractChannels(this.contentValue);
      const md = htmlToMarkdown(this.contentValue);
      this.editor.update(() => {
        $convertFromMarkdownString(md, TRANSFORMERS);
        if (mentions.size > 0 || channels.size > 0) {
          const root = this.lexical.$getRoot();
          restoreEntitiesInTree(root, mentions, channels, this.lexical, CodeNode);
        }
      });
    }

    this._mentionAC = new MentionAutocomplete({
      editor: this.editor,
      lexical: this.lexical,
      serverId: this.serverIdValue,
    });

    this._channelAC = new ChannelAutocomplete({
      editor: this.editor,
      lexical: this.lexical,
      serverId: this.serverIdValue,
    });

    this._slashAC = new SlashMenu({
      editor: this.editor,
      lexical: this.lexical,
      linked: this.hasChannelLinkedValue ? this.channelLinkedValue : false,
      commands: SLASH_COMMANDS,
    });

    this._cleanups = [];

    // Enter to send, Shift+Enter for newline
    this._cleanups.push(
      this.editor.registerCommand(
        KEY_ENTER_COMMAND,
        (event) => {
          if (this._mentionAC.isOpen) {
            event?.preventDefault();
            this._mentionAC.selectActive();
            return true;
          }
          if (this._channelAC.isOpen) {
            event?.preventDefault();
            this._channelAC.selectActive();
            return true;
          }
          if (this._slashAC.isOpen) {
            event?.preventDefault();
            this._slashAC.selectActive();
            return true;
          }
          // On touch devices, Enter inserts a newline — software keyboards
          // don't reliably fire keydown, so Enter-to-send is inconsistent.
          // Users tap the send button explicitly on mobile.
          if (event && !event.shiftKey && !this._isTouchDevice()) {
            event.preventDefault();
            this._submitMessage();
            return true;
          }
          return false;
        },
        COMMAND_PRIORITY_HIGH
      )
    );

    // Ensure code blocks are never the last node — append an empty paragraph
    // so the cursor always has somewhere to go after a code block
    this._cleanups.push(
      this.editor.registerUpdateListener(() => {
        this.editor.update(
          () => {
            const root = this.lexical.$getRoot();
            const lastChild = root.getLastChild();
            if (lastChild && this._isCodeNode(lastChild)) {
              root.append(this.lexical.$createParagraphNode());
            }
          },
          { tag: "history-merge" }
        );
      })
    );

    // Always paste as plain text — ignore rich HTML from other apps so pasted
    // content doesn't bring inconsistent formatting into the editor.
    this._cleanups.push(
      this.editor.registerCommand(
        PASTE_COMMAND,
        (event) => {
          const clipboardData = event instanceof ClipboardEvent ? event.clipboardData : null;
          if (!clipboardData) return false;

          const text = clipboardData.getData("text/plain");
          if (!text) return false;

          event.preventDefault();
          this.editor.update(() => {
            const selection = $getSelection();
            if ($isRangeSelection(selection)) {
              selection.insertRawText(text);
            }
          });
          return true;
        },
        COMMAND_PRIORITY_HIGH
      )
    );

    // Track active formats for toolbar button states, code block language picker, and mentions
    this._cleanups.push(
      this.editor.registerUpdateListener(({ editorState }) => {
        editorState.read(() => {
          const selection = $getSelection();
          if ($isRangeSelection(selection)) {
            this._updateToolbarState(selection);
            this._updateLanguagePicker(selection);
            this._mentionAC.checkTrigger(selection);
            this._channelAC.checkTrigger(selection);
            this._slashAC.checkTrigger(selection);
          }
          this._updatePlaceholder();
        });
      })
    );

    // Intercept arrow keys, Tab, and Escape for autocomplete dropdown navigation
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_ARROW_DOWN_COMMAND,
        (event) =>
          this._mentionAC.handleNav(event, "down") ||
          this._channelAC.handleNav(event, "down") ||
          this._slashAC.handleNav(event, "down"),
        lexical.COMMAND_PRIORITY_HIGH
      )
    );
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_ARROW_UP_COMMAND,
        (event) =>
          this._mentionAC.handleNav(event, "up") ||
          this._channelAC.handleNav(event, "up") ||
          this._slashAC.handleNav(event, "up"),
        lexical.COMMAND_PRIORITY_HIGH
      )
    );
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_TAB_COMMAND,
        (event) => {
          if (this._mentionAC.isOpen) {
            event.preventDefault();
            this._mentionAC.selectActive();
            return true;
          }
          if (this._channelAC.isOpen) {
            event.preventDefault();
            this._channelAC.selectActive();
            return true;
          }
          if (this._slashAC.isOpen) {
            event.preventDefault();
            this._slashAC.selectActive();
            return true;
          }
          return false;
        },
        lexical.COMMAND_PRIORITY_HIGH
      )
    );
    this._cleanups.push(
      this.editor.registerCommand(
        lexical.KEY_ESCAPE_COMMAND,
        () => {
          if (this._mentionAC.isOpen) {
            this._mentionAC.hideDropdown();
            return true;
          }
          if (this._channelAC.isOpen) {
            this._channelAC.hideDropdown();
            return true;
          }
          if (this._slashAC.isOpen) {
            this._slashAC.hideDropdown();
            return true;
          }
          return false;
        },
        lexical.COMMAND_PRIORITY_HIGH
      )
    );

    // Listen for quote events
    this._handleQuote = (e) => this._insertQuote(e.detail);
    document.addEventListener("message:quote", this._handleQuote);

    this._ready = true;
    this._submitting = false;
    this._updatePlaceholder();
    this.editorTarget.focus();
  }

  disconnect() {
    this.isDisconnecting = true;
    this._removeLanguagePicker();
    this._mentionAC?.destroy();
    this._channelAC?.destroy();
    this._slashAC?.destroy();

    if (this._handleQuote) {
      document.removeEventListener("message:quote", this._handleQuote);
      this._handleQuote = null;
    }
    if (this._autoLinkCleanup) {
      this._autoLinkCleanup();
      this._autoLinkCleanup = null;
    }
    if (this._cleanups) {
      this._cleanups.forEach((cleanup) => cleanup());
      this._cleanups = null;
    }
    if (this.editor) {
      this.editor.setRootElement(null);
      this.editor = null;
    }

    this._ready = false;
  }

  // Prevent toolbar buttons from stealing focus from the editor
  preventFocusLoss(event) {
    event.preventDefault();
  }

  // Toolbar actions
  bold(event) {
    event.preventDefault();
    if (!this._ready) return;
    this.editor.dispatchCommand(this.lexical.FORMAT_TEXT_COMMAND, "bold");
  }

  italic(event) {
    event.preventDefault();
    if (!this._ready) return;
    this.editor.dispatchCommand(this.lexical.FORMAT_TEXT_COMMAND, "italic");
  }

  strikethrough(event) {
    event.preventDefault();
    if (!this._ready) return;
    this.editor.dispatchCommand(this.lexical.FORMAT_TEXT_COMMAND, "strikethrough");
  }

  code(event) {
    event.preventDefault();
    if (!this._ready) return;
    this.editor.dispatchCommand(this.lexical.FORMAT_TEXT_COMMAND, "code");
  }

  codeBlock(event) {
    event.preventDefault();
    if (!this._ready) return;

    const { $getSelection, $isRangeSelection, $createTextNode } = this.lexical;
    const $createCodeNode = this._createCodeNode;

    this.editor.update(() => {
      const selection = $getSelection();
      if (!$isRangeSelection(selection)) return;

      const anchorNode = selection.anchor.getNode();
      const topLevelNode = anchorNode.getTopLevelElement();
      if (!topLevelNode) return;

      const codeNode = $createCodeNode();
      const textNode = $createTextNode("");
      codeNode.append(textNode);

      if (topLevelNode.getTextContent().trim() === "") {
        topLevelNode.replace(codeNode);
      } else {
        topLevelNode.insertAfter(codeNode);
      }
      textNode.select();
    });
  }

  // Editor resize actions
  resizeDefault(event) {
    event.preventDefault();
    this._applyEditorSize("default");
  }

  resizeHalf(event) {
    event.preventDefault();
    this._applyEditorSize("half");
  }

  resizeFull(event) {
    event.preventDefault();
    this._applyEditorSize("full");
  }

  _applyEditorSize(size) {
    const editor = this.editorTarget;

    if (size === "default") {
      editor.style.maxHeight = "12.5rem";
      editor.style.minHeight = "2.25rem";
    } else if (size === "half") {
      editor.style.maxHeight = "50vh";
      editor.style.minHeight = "50vh";
    } else if (size === "full") {
      const messageArea = this.element.closest(".flex-1.flex.flex-col.min-h-0.overflow-hidden");
      const areaHeight = messageArea ? messageArea.clientHeight : window.innerHeight - 100;
      const height = `${Math.max(200, areaHeight - 60)}px`;
      editor.style.maxHeight = height;
      editor.style.minHeight = height;
    }

    this.resizeBtnTargets.forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.size === size);
    });

    // Use Lexical's focus API rather than DOM focus(); on a contenteditable
    // a bare focus() can leave selection unset, which makes the editor look
    // blank (placeholder shows, focus-within border drops) until the user
    // clicks back into it.
    this.editor.focus();
  }

  // Reset after successful form submission
  reset() {
    this._submitting = false;
    this._setSubmitDisabled(false);
    if (this._submitTimeout) {
      clearTimeout(this._submitTimeout);
      this._submitTimeout = null;
    }

    if (!this._ready) return;

    this.editor.update(() => {
      const root = this.lexical.$getRoot();
      root.clear();
      root.append(this.lexical.$createParagraphNode());
    });

    this._applyEditorSize("default");
    this.editorTarget.focus();
  }

  // Private

  _registerAutoLink(lexical) {
    const URL_REGEX = /(?<![=\w])https?:\/\/[^\s<>)"']+/g;
    const { $isTextNode, $createTextNode, TextNode } = lexical;

    this._autoLinkCleanup = this.editor.registerNodeTransform(TextNode, (textNode) => {
      if (!$isTextNode(textNode)) return;

      const parent = textNode.getParent();
      if (this._$isAutoLinkNode(parent) || this._$isLinkNode(parent)) return;

      const text = textNode.getTextContent();
      const match = URL_REGEX.exec(text);
      URL_REGEX.lastIndex = 0;
      if (!match) return;

      const url = match[0];
      const start = match.index;
      const end = start + url.length;

      let targetNode = textNode;
      if (start > 0) {
        targetNode = textNode.splitText(start)[1];
      }
      if (end < text.length) {
        targetNode.splitText(url.length);
      }

      const linkNode = this._$createAutoLinkNode(url, {
        rel: "noopener noreferrer",
        target: "_blank",
      });
      const linkText = $createTextNode(url);
      linkNode.append(linkText);
      targetNode.replace(linkNode);
    });
  }

  handleSubmit(event) {
    if (this._submitting) {
      event.preventDefault();
      return;
    }

    const html = this._serializeToHtml();
    const hasFiles = this.element.querySelectorAll('input[name="message[files][]"]').length > 0;
    if (this._serializer.isEmpty(html) && !hasFiles) {
      event.preventDefault();
      return;
    }
    this.hiddenInputTarget.value = html;
    this._submitting = true;
    this._setSubmitDisabled(true);

    // Safety: re-enable after 3s in case turbo:submit-end doesn't fire
    this._submitTimeout = setTimeout(() => {
      this._submitting = false;
      this._setSubmitDisabled(false);
    }, 3000);
  }

  _submitMessage() {
    const html = this._serializeToHtml();
    const hasFiles = this.element.querySelectorAll('input[name="message[files][]"]').length > 0;
    if (this._serializer.isEmpty(html) && !hasFiles) return;

    this.hiddenInputTarget.value = html;
    this.element.requestSubmit();
  }

  _isTouchDevice() {
    return (
      typeof window !== "undefined" &&
      typeof window.matchMedia === "function" &&
      window.matchMedia("(pointer: coarse)").matches
    );
  }

  _serializeToHtml() {
    // Check for raw markdown and convert using a temp editor to get clean HTML,
    // without mutating the main editor state.
    // Mentions and channels are preserved through markdown conversion via placeholders.
    let plainText = "";
    const entities = [];
    this.editor.getEditorState().read(() => {
      plainText = getTextWithPlaceholders(this.lexical.$getRoot(), entities);
    });

    if (plainText && this._serializer.looksLikeMarkdown(plainText)) {
      // Each blank line between blocks is \n\n\n\n (two block separators with
      // an empty paragraph between). Replace each extra \n\n with a placeholder
      // paragraph that the markdown converter won't swallow.
      const BLANK_LINE = "\x00BLANKLINE\x00";
      const normalized = plainText
        .replace(/\n+$/, "")
        .replace(/\n\n\n\n/g, `\n\n${BLANK_LINE}\n\n`)
        // Flatten nested blockquotes (>> or > > >) to single >
        .replace(/^(?:>\s*){2,}/gm, "> ");
      const tempEditor = this.lexical.createEditor({
        namespace: "MarkdownTemp",
        nodes: this._editorNodes,
      });
      const tempEl = document.createElement("div");
      tempEditor.setRootElement(tempEl);
      tempEditor.update(
        () => {
          this._$convertFromMarkdownString(normalized, this._TRANSFORMERS);
        },
        { discrete: true }
      );

      let html = "";
      tempEditor.getEditorState().read(() => {
        html = this.htmlModule.$generateHtmlFromNodes(tempEditor);
      });
      tempEditor.setRootElement(null);
      html = restoreEntityPlaceholders(html, entities);
      // Replace placeholder paragraphs with empty paragraphs for visual spacing
      html = html.split(`<p>${BLANK_LINE}</p>`).join("<p><br></p>");
      html = html.split(BLANK_LINE).join("");
      return this._serializer.cleanHtml(html);
    }

    let html = "";
    this.editor.getEditorState().read(() => {
      html = this.htmlModule.$generateHtmlFromNodes(this.editor);
    });
    return this._serializer.cleanHtml(html);
  }

  _updateToolbarState(selection) {
    const formatButtons = {
      bold: this.element.querySelector('[data-format="bold"]'),
      italic: this.element.querySelector('[data-format="italic"]'),
      strikethrough: this.element.querySelector('[data-format="strikethrough"]'),
      code: this.element.querySelector('[data-format="code"]'),
    };

    for (const [format, button] of Object.entries(formatButtons)) {
      if (!button) continue;
      if (selection.hasFormat(format)) {
        button.classList.add("active");
      } else {
        button.classList.remove("active");
      }
    }
  }

  _updateLanguagePicker(selection) {
    const anchorNode = selection.anchor.getNode();
    let codeNode = null;
    let node = anchorNode;
    while (node) {
      if (this._isCodeNode(node)) {
        codeNode = node;
        break;
      }
      node = node.getParent();
    }

    if (!codeNode) {
      this._removeLanguagePicker();
      return;
    }

    const codeNodeKey = codeNode.getKey();
    if (this._langPickerNodeKey === codeNodeKey) return;

    this._removeLanguagePicker();
    this._langPickerNodeKey = codeNodeKey;

    const codeDomElement = this.editor.getElementByKey(codeNodeKey);
    if (!codeDomElement) return;

    const editorWrapper = this.editorTarget.parentElement;
    const wrapperRect = editorWrapper.getBoundingClientRect();
    const codeRect = codeDomElement.getBoundingClientRect();

    const picker = document.createElement("select");
    picker.className = "code-lang-picker";
    picker.innerHTML = this._languageOptions(codeNode.getLanguage());
    picker.style.top = `${codeRect.top - wrapperRect.top + 4}px`;
    picker.style.right = "4px";

    picker.addEventListener("mousedown", (e) => {
      e.stopPropagation();
    });
    picker.addEventListener("change", (e) => {
      const lang = e.target.value;
      this.editor.update(() => {
        const node = this.lexical.$getNodeByKey(codeNodeKey);
        if (node && this._isCodeNode(node)) {
          node.setLanguage(lang || null);
        }
      });
    });

    editorWrapper.appendChild(picker);
    this._langPicker = picker;
  }

  _removeLanguagePicker() {
    if (this._langPicker) {
      this._langPicker.remove();
      this._langPicker = null;
      this._langPickerNodeKey = null;
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
      ["plaintext", "plain"],
    ];
    return langs
      .map(([value, label]) => {
        const selected = value === (current || "") ? " selected" : "";
        return `<option value="${value}"${selected}>${label}</option>`;
      })
      .join("");
  }

  _setSubmitDisabled(disabled) {
    const btn = this.element.querySelector('input[type="submit"]');
    if (btn) {
      btn.disabled = disabled;
      btn.style.opacity = disabled ? "0.4" : "";
    }
  }

  _insertQuote({ body }) {
    if (!this._ready || !body) return;

    const escaped = body.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    const quoteHtml = `<blockquote><p>${escaped}</p></blockquote><p></p>`;

    this.editor.update(() => {
      const parser = new DOMParser();
      const dom = parser.parseFromString(quoteHtml, "text/html");
      const nodes = this.htmlModule.$generateNodesFromDOM(this.editor, dom);

      const root = this.lexical.$getRoot();
      const firstChild = root.getFirstChild();
      const isEmpty = root.getChildrenSize() === 1 && firstChild?.getTextContent().trim() === "";

      if (isEmpty) {
        root.clear();
      }

      nodes.forEach((node) => root.append(node));

      const lastChild = root.getLastChild();
      if (lastChild) lastChild.select();
    });

    this.editorTarget.focus();
  }

  _updatePlaceholder() {
    if (!this.hasPlaceholderTarget || !this.editor) return;

    this.editor.getEditorState().read(() => {
      const root = this.lexical.$getRoot();
      const textContent = root.getTextContent();
      this.placeholderTarget.style.display = textContent.length === 0 ? "" : "none";
    });
  }
}
