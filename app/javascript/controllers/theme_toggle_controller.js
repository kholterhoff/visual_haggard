import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "visual-haggard-theme"

export default class extends Controller {
  connect() {
    this.handleSystemChange = this.handleSystemChange.bind(this)
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")

    if (typeof this.mediaQuery.addEventListener === "function") {
      this.mediaQuery.addEventListener("change", this.handleSystemChange)
    } else {
      this.mediaQuery.addListener(this.handleSystemChange)
    }

    this.sync()
  }

  disconnect() {
    if (!this.mediaQuery) return

    if (typeof this.mediaQuery.removeEventListener === "function") {
      this.mediaQuery.removeEventListener("change", this.handleSystemChange)
    } else {
      this.mediaQuery.removeListener(this.handleSystemChange)
    }
  }

  toggle() {
    const nextTheme = this.currentTheme() === "dark" ? "light" : "dark"

    this.writeStoredTheme(nextTheme)
    this.applyTheme(nextTheme)
    this.sync()
  }

  handleSystemChange() {
    if (this.storedTheme()) return

    this.sync()
  }

  sync() {
    const storedTheme = this.storedTheme()
    const theme = this.currentTheme()
    const nextLabel = theme === "dark" ? "Switch to light mode" : "Switch to dark mode"

    this.applyTheme(storedTheme)
    this.element.dataset.activeTheme = theme
    this.element.setAttribute("aria-label", nextLabel)
    this.element.setAttribute("aria-pressed", String(theme === "dark"))
    this.element.setAttribute("title", nextLabel)
  }

  currentTheme() {
    return this.storedTheme() || (this.mediaQuery.matches ? "dark" : "light")
  }

  applyTheme(theme) {
    if (theme === "light" || theme === "dark") {
      document.documentElement.dataset.theme = theme
    } else {
      delete document.documentElement.dataset.theme
    }
  }

  storedTheme() {
    try {
      const theme = window.localStorage.getItem(STORAGE_KEY)
      return theme === "light" || theme === "dark" ? theme : null
    } catch (_error) {
      return null
    }
  }

  writeStoredTheme(theme) {
    try {
      window.localStorage.setItem(STORAGE_KEY, theme)
    } catch (_error) {
      return
    }
  }
}
