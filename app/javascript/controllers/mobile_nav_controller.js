import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    this.element.classList.add("mobile-nav-ready")
    this.syncForViewport()
  }

  disconnect() {
    this.element.classList.remove("mobile-nav-ready")
  }

  toggle() {
    if (!this.isMobileViewport()) return

    this.setOpen(!this.panelTarget.classList.contains("is-open"), { moveFocus: true })
  }

  close(event) {
    if (!this.isMobileViewport()) return

    this.setOpen(false, { restoreFocus: event?.type === "keydown" })
  }

  closeOnOutside(event) {
    if (!this.isMobileViewport()) return
    if (!this.panelTarget.classList.contains("is-open")) return
    if (this.element.contains(event.target)) return

    this.setOpen(false)
  }

  syncForViewport() {
    if (!this.isMobileViewport()) {
      this.panelTarget.classList.remove("is-open")
    }

    this.syncButton()
    this.syncPanel()
  }

  syncButton() {
    this.buttonTarget.setAttribute(
      "aria-expanded",
      String(this.panelTarget.classList.contains("is-open"))
    )
  }

  syncPanel() {
    const shouldHide = this.isMobileViewport() && !this.panelTarget.classList.contains("is-open")
    this.panelTarget.hidden = shouldHide
    this.panelTarget.setAttribute("aria-hidden", String(shouldHide))
  }

  setOpen(open, { restoreFocus = false, moveFocus = false } = {}) {
    this.panelTarget.classList.toggle("is-open", open)
    this.syncButton()
    this.syncPanel()

    if (open && moveFocus) {
      window.requestAnimationFrame(() => this.firstFocusableInPanel()?.focus())
    }

    if (!open && restoreFocus) {
      window.requestAnimationFrame(() => this.buttonTarget.focus())
    }
  }

  isMobileViewport() {
    return window.innerWidth <= 780
  }

  firstFocusableInPanel() {
    return this.panelTarget.querySelector(
      "a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])"
    )
  }
}
