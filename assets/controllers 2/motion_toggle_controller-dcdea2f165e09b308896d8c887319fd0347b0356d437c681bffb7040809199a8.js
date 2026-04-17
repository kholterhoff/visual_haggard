import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.paused = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.sync()
  }

  toggle() {
    this.paused = !this.paused
    this.sync()
    this.dispatch("change", { detail: { paused: this.paused } })
  }

  sync() {
    this.element.dataset.motionState = this.paused ? "paused" : "running"

    if (!this.hasButtonTarget) return

    this.buttonTarget.setAttribute("aria-pressed", String(this.paused))
    this.buttonTarget.textContent = this.paused ? "Play motion" : "Pause motion"
  }
};
