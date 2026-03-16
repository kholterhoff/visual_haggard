import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "dot", "pauseButton"]
  static values = { interval: { type: Number, default: 6000 } }

  connect() {
    this.userPaused = false
    this.handleMotionChange = this.handleMotionChange.bind(this)
    this.motionContainer = this.element.closest("[data-controller~='motion-toggle']")
    this.motionContainer?.addEventListener("motion-toggle:change", this.handleMotionChange)

    this.currentIndex = this.slideTargets.findIndex((slide) => slide.classList.contains("is-active"))
    if (this.currentIndex < 0) this.currentIndex = 0

    this.show(this.currentIndex)
    this.syncPauseButton()
    this.start()
  }

  disconnect() {
    this.motionContainer?.removeEventListener("motion-toggle:change", this.handleMotionChange)
    this.stop()
  }

  next() {
    if (this.slideTargets.length < 2) return
    this.show((this.currentIndex + 1) % this.slideTargets.length)
  }

  previous() {
    if (this.slideTargets.length < 2) return
    this.show((this.currentIndex - 1 + this.slideTargets.length) % this.slideTargets.length)
  }

  select(event) {
    const index = Number(event.params.index)
    if (Number.isNaN(index)) return

    this.show(index)
    this.start()
  }

  togglePause() {
    this.userPaused = !this.userPaused
    this.syncPauseButton()

    if (this.userPaused) {
      this.stop()
    } else {
      this.start()
    }
  }

  pause() {
    if (this.userPaused) return

    this.stop()
  }

  resume() {
    if (this.userPaused) return

    this.start()
  }

  start() {
    if (this.slideTargets.length < 2) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (this.userPaused) return
    if (this.motionContainer?.dataset.motionState === "paused") return

    this.stop()
    this.timer = window.setInterval(() => this.next(), this.intervalValue)
  }

  stop() {
    if (!this.timer) return

    window.clearInterval(this.timer)
    this.timer = null
  }

  show(index) {
    this.currentIndex = index

    this.slideTargets.forEach((slide, slideIndex) => {
      const active = slideIndex === index
      slide.classList.toggle("is-active", active)
      slide.setAttribute("aria-hidden", String(!active))
      slide.inert = !active
    })

    this.dotTargets.forEach((dot, dotIndex) => {
      const active = dotIndex === index
      dot.classList.toggle("is-active", active)
      dot.setAttribute("aria-current", active ? "true" : "false")
    })
  }

  handleMotionChange(event) {
    if (event.detail.paused) {
      this.stop()
    } else if (!this.userPaused) {
      this.start()
    }
  }

  syncPauseButton() {
    if (!this.hasPauseButtonTarget) return

    this.pauseButtonTarget.setAttribute("aria-pressed", String(this.userPaused))
    this.pauseButtonTarget.textContent = this.userPaused ? "Play motion" : "Pause motion"
  }
}
