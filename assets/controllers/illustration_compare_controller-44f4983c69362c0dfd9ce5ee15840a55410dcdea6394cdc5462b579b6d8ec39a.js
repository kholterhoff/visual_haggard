import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "trigger"]

  connect() {
    this.syncTrigger(false)
  }

  open(event) {
    event.preventDefault()
    if (!this.hasDialogTarget) return

    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "open")
    }

    this.syncTrigger(true)
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return

    if (typeof this.dialogTarget.close === "function" && this.dialogTarget.open) {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
      this.handleClose()
    }
  }

  handleCancel() {
    this.syncTrigger(false)
  }

  handleClose() {
    this.syncTrigger(false)

    if (this.hasTriggerTarget) {
      window.requestAnimationFrame(() => this.triggerTarget.focus())
    }
  }

  closeOnBackdrop(event) {
    if (event.target !== this.dialogTarget) return

    const rect = this.dialogTarget.getBoundingClientRect()
    const clickedInsideDialog =
      event.clientX >= rect.left &&
      event.clientX <= rect.right &&
      event.clientY >= rect.top &&
      event.clientY <= rect.bottom

    if (!clickedInsideDialog) {
      this.close()
    }
  }

  syncTrigger(open) {
    if (!this.hasTriggerTarget) return

    this.triggerTarget.setAttribute("aria-expanded", String(open))
  }
};
