import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["reel", "sequence", "image"]

  connect() {
    this.measure = this.measure.bind(this)
    this.handleResize = this.handleResize.bind(this)
    this.revealIfReady = this.revealIfReady.bind(this)
    this.ready = false

    this.resizeObserver = new ResizeObserver(() => this.measure())
    this.sequenceTargets.forEach((sequence) => this.resizeObserver.observe(sequence))

    window.addEventListener("resize", this.handleResize)

    this.awaitInitialLayout()
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    window.removeEventListener("resize", this.handleResize)
    window.clearTimeout(this.fallbackTimer)
  }

  handleResize() {
    window.requestAnimationFrame(this.measure)
  }

  async awaitInitialLayout() {
    const visibleImages = this.imageTargets.filter((image) => image.closest("[aria-hidden='true']") === null)
    this.fallbackTimer = window.setTimeout(this.revealIfReady, 1400)

    if (visibleImages.length === 0) {
      this.revealIfReady()
      return
    }

    await Promise.all(visibleImages.map((image) => this.waitForImage(image)))
    requestAnimationFrame(() => this.revealIfReady())
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

  revealIfReady() {
    if (this.ready) return

    this.measure()
    this.element.dataset.reelsReady = "true"
    this.ready = true
    window.clearTimeout(this.fallbackTimer)
  }

  waitForImage(image) {
    if (image.complete) return Promise.resolve()

    return new Promise((resolve) => {
      const complete = () => {
        image.removeEventListener("load", complete)
        image.removeEventListener("error", complete)
        resolve()
      }

      image.addEventListener("load", complete, { once: true })
      image.addEventListener("error", complete, { once: true })
    })
  }
}
