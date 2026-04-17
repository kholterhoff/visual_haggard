import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track"]

  previous() {
    this.scrollBy(-1)
  }

  next() {
    this.scrollBy(1)
  }

  scrollBy(direction) {
    if (!this.hasTrackTarget) return

    const distance = Math.max(this.trackTarget.clientWidth * 0.72, 320) * direction
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    this.trackTarget.scrollBy({
      left: distance,
      behavior: prefersReducedMotion ? "auto" : "smooth"
    })
  }
};
