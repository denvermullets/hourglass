import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]
  static values = { channelName: String }

  connect() {
    this.dragCounter = 0
    this._onDragEnter = this._handleDragEnter.bind(this)
    this._onDragLeave = this._handleDragLeave.bind(this)
    this._onDragOver = this._handleDragOver.bind(this)
    this._onDrop = this._handleDrop.bind(this)

    this.element.addEventListener("dragenter", this._onDragEnter)
    this.element.addEventListener("dragleave", this._onDragLeave)
    this.element.addEventListener("dragover", this._onDragOver)
    this.element.addEventListener("drop", this._onDrop)
  }

  disconnect() {
    this.element.removeEventListener("dragenter", this._onDragEnter)
    this.element.removeEventListener("dragleave", this._onDragLeave)
    this.element.removeEventListener("dragover", this._onDragOver)
    this.element.removeEventListener("drop", this._onDrop)
  }

  _handleDragEnter(event) {
    event.preventDefault()
    this.dragCounter++
    if (this.dragCounter === 1) this._showOverlay()
  }

  _handleDragLeave(event) {
    event.preventDefault()
    this.dragCounter--
    if (this.dragCounter === 0) this._hideOverlay()
  }

  _handleDragOver(event) {
    event.preventDefault()
  }

  _handleDrop(event) {
    event.preventDefault()
    this.dragCounter = 0
    this._hideOverlay()

    const files = Array.from(event.dataTransfer.files)
    if (files.length === 0) return

    // Find the attachment-upload controller on the form within this area
    const form = this.element.querySelector("[data-controller~='attachment-upload']")
    if (!form) return

    const uploadController = this.application.getControllerForElementAndIdentifier(form, "attachment-upload")
    if (uploadController) {
      files.forEach(file => uploadController.addFile(file))
    }
  }

  _showOverlay() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
    }
  }

  _hideOverlay() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
    }
  }
}
