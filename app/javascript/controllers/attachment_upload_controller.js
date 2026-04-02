import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["fileInput", "previewStrip"]
  static values = {
    maxFiles: { type: Number, default: 10 },
    maxSize: { type: Number, default: 52428800 }, // 50MB
    url: { type: String, default: "/rails/active_storage/direct_uploads" }
  }

  static ALLOWED_TYPES = [
    "image/jpeg", "image/png", "image/gif", "image/webp",
    "video/mp4", "video/webm", "video/quicktime",
    "application/pdf", "application/zip",
    "audio/mpeg", "audio/wav", "audio/ogg",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "text/plain", "text/markdown"
  ]

  connect() {
    this.pendingFiles = []
  }

  disconnect() {
    this.pendingFiles.forEach(pf => {
      if (pf.previewUrl) URL.revokeObjectURL(pf.previewUrl)
    })
    this.pendingFiles = []
  }

  openFilePicker() {
    this.fileInputTarget.click()
  }

  filesSelected(event) {
    const files = Array.from(event.target.files)
    files.forEach(file => this.addFile(file))
    // Reset input so the same file can be re-selected
    this.fileInputTarget.value = ""
  }

  handlePaste(event) {
    const items = event.clipboardData?.items
    if (!items) return

    for (const item of items) {
      if (item.kind === "file") {
        const file = item.getAsFile()
        if (file) this.addFile(file)
      }
    }
  }

  handleDrop(event) {
    event.preventDefault()
    const files = Array.from(event.dataTransfer.files)
    files.forEach(file => this.addFile(file))
  }

  handleDragOver(event) {
    event.preventDefault()
  }

  addFile(file) {
    // Validate count
    if (this.pendingFiles.length >= this.maxFilesValue) {
      this._showError(`Maximum ${this.maxFilesValue} files allowed`)
      return
    }

    // Validate size
    if (file.size > this.maxSizeValue) {
      this._showError(`${file.name} is too large (max 50MB)`)
      return
    }

    // Validate type
    if (!this.constructor.ALLOWED_TYPES.includes(file.type)) {
      this._showError(`${file.name} has an unsupported file type`)
      return
    }

    const entry = {
      id: crypto.randomUUID(),
      file,
      signedId: null,
      previewUrl: file.type.startsWith("image/") ? URL.createObjectURL(file) : null,
      uploading: true,
      progress: 0
    }

    this.pendingFiles.push(entry)
    this._renderPreviewStrip()
    this._uploadFile(entry)
  }

  removeFile(event) {
    const id = event.currentTarget.dataset.fileId
    const index = this.pendingFiles.findIndex(pf => pf.id === id)
    if (index === -1) return

    const entry = this.pendingFiles[index]
    if (entry.previewUrl) URL.revokeObjectURL(entry.previewUrl)

    // Remove hidden input if already uploaded
    const hiddenInput = this.element.querySelector(`input[data-file-id="${id}"]`)
    if (hiddenInput) hiddenInput.remove()

    this.pendingFiles.splice(index, 1)
    this._renderPreviewStrip()
  }

  // Remove an existing attachment (during message editing)
  removeExistingFile(event) {
    const fileId = event.currentTarget.dataset.fileId
    const thumb = event.currentTarget.closest("[data-existing-file]")
    if (thumb) thumb.remove()

    // Add hidden input to mark this file for purging
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "message[purge_file_ids][]"
    input.value = fileId
    this.element.appendChild(input)

    // Hide the strip if no files remain (existing or pending)
    this._updateStripVisibility()
  }

  _updateStripVisibility() {
    if (!this.hasPreviewStripTarget) return
    const hasExisting = this.previewStripTarget.querySelector("[data-existing-file]")
    const hasPending = this.pendingFiles.length > 0
    if (!hasExisting && !hasPending) {
      this.previewStripTarget.classList.add("hidden")
    }
  }

  reset() {
    this.pendingFiles.forEach(pf => {
      if (pf.previewUrl) URL.revokeObjectURL(pf.previewUrl)
    })
    this.pendingFiles = []

    // Remove all file hidden inputs
    this.element.querySelectorAll('input[name="message[files][]"]').forEach(el => el.remove())
    this._renderPreviewStrip()
  }

  // Direct upload with progress
  _uploadFile(entry) {
    const upload = new DirectUpload(entry.file, this.urlValue, {
      directUploadWillStoreFileWithXHR: (request) => {
        request.upload.addEventListener("progress", (event) => {
          if (event.lengthComputable) {
            entry.progress = Math.round((event.loaded / event.total) * 100)
            this._updateProgress(entry)
          }
        })
      }
    })

    upload.create((error, blob) => {
      if (error) {
        this._showError(`Failed to upload ${entry.file.name}`)
        const index = this.pendingFiles.findIndex(pf => pf.id === entry.id)
        if (index !== -1) {
          if (entry.previewUrl) URL.revokeObjectURL(entry.previewUrl)
          this.pendingFiles.splice(index, 1)
          this._renderPreviewStrip()
        }
        return
      }

      entry.signedId = blob.signed_id
      entry.uploading = false
      entry.progress = 100

      // Append hidden input with signed blob ID
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "message[files][]"
      input.value = blob.signed_id
      input.dataset.fileId = entry.id
      this.element.appendChild(input)

      this._updateProgress(entry)
    })
  }

  _renderPreviewStrip() {
    if (!this.hasPreviewStripTarget) return

    const hasExisting = this.previewStripTarget.querySelector("[data-existing-file]")

    if (this.pendingFiles.length === 0 && !hasExisting) {
      this.previewStripTarget.classList.add("hidden")
      // Only clear if no existing files
      if (!hasExisting) this.previewStripTarget.innerHTML = ""
      return
    }

    this.previewStripTarget.classList.remove("hidden")

    // Remove old pending thumbs and the "+" button, but keep existing file thumbs
    this.previewStripTarget.querySelectorAll("[data-pending-file], [data-add-more]").forEach(el => el.remove())

    // Append new pending file thumbs
    this.pendingFiles.forEach(entry => {
      const html = entry.file.type.startsWith("image/") && entry.previewUrl
        ? this._imageThumbHtml(entry)
        : this._fileThumbHtml(entry)
      this.previewStripTarget.insertAdjacentHTML("beforeend", html)
    })

    // Add "+" button
    this.previewStripTarget.insertAdjacentHTML("beforeend", `
      <button type="button" data-action="click->attachment-upload#openFilePicker" data-add-more
              class="flex items-center justify-center w-[52px] h-[52px] border border-dashed border-bunker-825 rounded cursor-pointer flex-shrink-0 hover:border-bunker-700 transition-colors duration-150">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" class="text-bunker-700" stroke-width="1.5" stroke-linecap="round">
          <line x1="12" y1="5" x2="12" y2="19"></line>
          <line x1="5" y1="12" x2="19" y2="12"></line>
        </svg>
      </button>
    `)
  }

  _imageThumbHtml(entry) {
    const progressBar = entry.uploading
      ? `<div class="absolute bottom-0 left-0 right-0 h-0.5 bg-bunker-825"><div class="h-full bg-granny-smith-apple-600 transition-all duration-200" style="width: ${entry.progress}%" data-progress-id="${entry.id}"></div></div>`
      : ""

    return `
      <div class="w-[52px] h-[52px] rounded flex-shrink-0 relative overflow-hidden border border-bunker-825 bg-bunker-875" data-pending-file>
        <img src="${entry.previewUrl}" class="w-full h-full object-cover" />
        <button type="button" data-action="click->attachment-upload#removeFile" data-file-id="${entry.id}"
                class="absolute top-0.5 right-0.5 w-3.5 h-3.5 rounded-full bg-bunker-950/90 border border-bunker-825 flex items-center justify-center text-[8px] text-bunker-400 cursor-pointer leading-none hover:text-bunker-100">&times;</button>
        ${progressBar}
      </div>
    `
  }

  _fileThumbHtml(entry) {
    const ext = entry.file.name.split(".").pop().toUpperCase()
    const extColor = this._extColor(entry.file.type, ext)
    const progressBar = entry.uploading
      ? `<div class="absolute bottom-0 left-0 right-0 h-0.5 bg-bunker-825"><div class="h-full bg-granny-smith-apple-600 transition-all duration-200" style="width: ${entry.progress}%" data-progress-id="${entry.id}"></div></div>`
      : ""

    return `
      <div class="w-[52px] h-[52px] rounded flex-shrink-0 relative border border-bunker-825 bg-bunker-875 flex flex-col items-center justify-center gap-0.5" data-pending-file>
        <span class="text-[8px] font-medium ${extColor}">${ext}</span>
        <span class="text-[6px] text-bunker-700 text-center px-0.5 truncate max-w-full">${entry.file.name}</span>
        <button type="button" data-action="click->attachment-upload#removeFile" data-file-id="${entry.id}"
                class="absolute top-0.5 right-0.5 w-3.5 h-3.5 rounded-full bg-bunker-950/90 border border-bunker-825 flex items-center justify-center text-[8px] text-bunker-400 cursor-pointer leading-none hover:text-bunker-100">&times;</button>
        ${progressBar}
      </div>
    `
  }

  _extColor(type, ext) {
    if (type === "application/pdf") return "text-danger-400"
    if (type.startsWith("audio/")) return "text-purple-400"
    if (type === "application/zip") return "text-yellow-400"
    if (type.includes("word") || type.includes("document")) return "text-jordy-blue-400"
    return "text-bunker-400"
  }

  _updateProgress(entry) {
    const bar = this.previewStripTarget?.querySelector(`[data-progress-id="${entry.id}"]`)
    if (bar) {
      bar.style.width = `${entry.progress}%`
      if (!entry.uploading) {
        // Remove progress bar after a short delay
        setTimeout(() => {
          const wrapper = bar.closest(".absolute")
          if (wrapper) wrapper.remove()
        }, 500)
      }
    }
  }

  _showError(message) {
    // Create a temporary error toast
    const toast = document.createElement("div")
    toast.className = "fixed bottom-4 left-1/2 -translate-x-1/2 bg-danger-800 text-danger-400 text-[10px] font-dm-mono px-4 py-2 rounded border border-danger-800 z-50"
    toast.textContent = message
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 3000)
  }
}
