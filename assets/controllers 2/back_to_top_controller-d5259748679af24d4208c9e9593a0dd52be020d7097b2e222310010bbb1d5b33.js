import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "item"]
  static values = {
    minimumItems: { type: Number, default: 12 },
    rowThreshold: { type: Number, default: 4 },
    offset: { type: Number, default: 112 }
  }

  connect() {
    this.updateVisibility = this.updateVisibility.bind(this)
    this.onScroll = this.onScroll.bind(this)

    if (!this.shouldEnable()) {
      this.hide()
      return
    }

    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.updateVisibility)
    this.updateVisibility()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.updateVisibility)
  }

  scroll() {
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    window.scrollTo({
      top: 0,
      behavior: prefersReducedMotion ? "auto" : "smooth"
    })

    this.buttonTarget.blur()
  }

  onScroll() {
    if (this.raf) return

    this.raf = window.requestAnimationFrame(() => {
      this.raf = null
      this.updateVisibility()
    })
  }

  updateVisibility() {
    if (!this.shouldEnable()) {
      this.hide()
      return
    }

    const thresholdItem = this.thresholdItem()
    if (!thresholdItem) {
      this.hide()
      return
    }

    const shouldShow = thresholdItem.getBoundingClientRect().top <= this.offsetValue
    this.buttonTarget.classList.toggle("is-visible", shouldShow)
    this.buttonTarget.hidden = !shouldShow
  }

  shouldEnable() {
    return this.hasButtonTarget && this.itemTargets.length > this.minimumItemsValue
  }

  thresholdItem() {
    const columns = this.detectColumns()
    const thresholdIndex = Math.min(this.itemTargets.length - 1, (columns * this.rowThresholdValue) - 1)
    return this.itemTargets[thresholdIndex]
  }

  detectColumns() {
    if (this.itemTargets.length === 0) return 1

    const firstRowTop = this.itemTargets[0].offsetTop
    let columns = 0

    for (const item of this.itemTargets) {
      if (item.offsetTop !== firstRowTop) break
      columns += 1
    }

    return Math.max(columns, 1)
  }

  hide() {
    if (!this.hasButtonTarget) return

    this.buttonTarget.classList.remove("is-visible")
    this.buttonTarget.hidden = true
  }
};
