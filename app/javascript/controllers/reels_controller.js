import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["reel", "sequence"]

  connect() {
    this.measure = this.measure.bind(this)
    this.handleResize = this.handleResize.bind(this)

    this.resizeObserver = new ResizeObserver(() => this.measure())
    this.sequenceTargets.forEach((sequence) => this.resizeObserver.observe(sequence))

    window.addEventListener("resize", this.handleResize)
    requestAnimationFrame(() => this.measure())
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    window.removeEventListener("resize", this.handleResize)
  }

  handleResize() {
    window.requestAnimationFrame(this.measure)
  }

  measure() {
    this.reelTargets.forEach((reel) => {
      const sequence = reel.querySelector("[data-reels-target='sequence']")
      const track = reel.querySelector(".home-cover-reel-track")
      if (!sequence) return

      const sequenceGap = track ? Number.parseFloat(window.getComputedStyle(track).rowGap) || 0 : 0

      reel.style.setProperty("--reel-distance", `${sequence.offsetHeight + sequenceGap}px`)
    })
  }
}
