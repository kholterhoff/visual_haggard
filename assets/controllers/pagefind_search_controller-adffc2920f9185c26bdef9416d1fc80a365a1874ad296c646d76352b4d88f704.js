import { Controller } from "@hotwired/stimulus"

const SECTION_CONFIG = {
  illustrations: {
    filter: "illustration",
    singular: "illustration",
    batchSize: 24,
    sectionId: "pagefind-search-illustrations",
    label: "Illustration"
  },
  novels: {
    filter: "novel",
    singular: "novel",
    batchSize: 12,
    sectionId: "pagefind-search-novels",
    label: "Novel"
  },
  editions: {
    filter: "edition",
    singular: "edition",
    batchSize: 18,
    sectionId: "pagefind-search-editions",
    label: "Edition"
  },
  illustrators: {
    filter: "illustrator",
    singular: "illustrator",
    batchSize: 18,
    sectionId: "pagefind-search-illustrators",
    label: "Illustrator"
  }
}

export default class extends Controller {
  static targets = [
    "fallback",
    "shell",
    "status",
    "jumpChips",
    "illustrationsSection",
    "illustrationsCount",
    "illustrationsResults",
    "illustrationsMore",
    "novelsSection",
    "novelsCount",
    "novelsResults",
    "novelsMore",
    "editionsSection",
    "editionsCount",
    "editionsResults",
    "editionsMore",
    "illustratorsSection",
    "illustratorsCount",
    "illustratorsResults",
    "illustratorsMore"
  ]

  static values = {
    query: String
  }

  connect() {
    this.query = this.currentQuery()
    this.resultHandles = {}
    this.renderedCounts = {}

    if (!this.query) return

    this.initializeSearch()
  }

  async initializeSearch() {
    let pagefind

try {
  pagefind = await import("/pagefind/pagefind.js")
} catch (error) {
  console.error("Pagefind could not be loaded", error)
  if (this.query !== this.queryValue) {
    this.shellTarget.hidden = false
    this.showStatus("Static search is unavailable right now. Rebuild the Pagefind index before previewing the published archive.")
  }
  return
}
    this.activateShell()
    this.showStatus(`Searching the archive for <strong>${this.escapeHtml(this.query)}</strong>…`)

    try {
      const searches = await Promise.all(
        Object.entries(SECTION_CONFIG).map(async ([key, config]) => {
          const response = await pagefind.search(this.query, {
            filters: { record_type: config.filter }
          })

          return [key, response.results || []]
        })
      )

      this.resultHandles = Object.fromEntries(searches)

      const totalMatches = Object.values(this.resultHandles).reduce((sum, results) => sum + results.length, 0)
      this.renderJumpChips()

      if (!totalMatches) {
        this.hideAllSections()
        this.showStatus(`No results were found for <strong>${this.escapeHtml(this.query)}</strong>.`)
        return
      }

      this.hideStatus()
      await Promise.all(Object.keys(SECTION_CONFIG).map((key) => this.renderNextBatch(key, { reset: true })))
    } catch (error) {
      console.error("Pagefind search failed", error)
      this.hideAllSections()
      this.showStatus("Static search is unavailable right now. Rebuild the Pagefind index before previewing the published archive.")
    }
  }

  async loadMore(event) {
    const type = event.params.type
    if (!SECTION_CONFIG[type]) return

    await this.renderNextBatch(type)
  }

  activateShell() {
    this.shellTarget.hidden = false
    this.fallbackTarget.hidden = true
  }

  currentQuery() {
    const params = new URLSearchParams(window.location.search)
    return (params.get("search") || params.get("q") || this.queryValue || "").trim()
  }

  async renderNextBatch(type, { reset = false } = {}) {
    const config = SECTION_CONFIG[type]
    const handles = this.resultHandles[type] || []
    const sectionTarget = this[`${type}SectionTarget`]
    const countTarget = this[`${type}CountTarget`]
    const resultsTarget = this[`${type}ResultsTarget`]
    const moreTarget = this[`${type}MoreTarget`]

    countTarget.textContent = this.formatNumber(handles.length)

    if (!handles.length) {
      sectionTarget.hidden = true
      resultsTarget.innerHTML = ""
      moreTarget.hidden = true
      this.renderedCounts[type] = 0
      return
    }

    if (reset) {
      resultsTarget.innerHTML = ""
      this.renderedCounts[type] = 0
    }

    const alreadyRendered = this.renderedCounts[type] || 0
    const nextHandles = handles.slice(alreadyRendered, alreadyRendered + config.batchSize)
    const records = await Promise.all(nextHandles.map((handle) => handle.data()))

    resultsTarget.insertAdjacentHTML(
      "beforeend",
      records.map((record) => this.renderRecord(type, record)).join("")
    )

    this.renderedCounts[type] = alreadyRendered + records.length
    sectionTarget.hidden = false
    moreTarget.hidden = this.renderedCounts[type] >= handles.length
  }

  renderJumpChips() {
    const chipTypes = ["illustrations", "novels", "editions"]
    const chips = chipTypes
      .filter((type) => (this.resultHandles[type] || []).length > 0)
      .map((type) => {
        const config = SECTION_CONFIG[type]
        const count = this.resultHandles[type].length
        return `
          <a class="meta-chip meta-chip-link" href="#${config.sectionId}">
            ${this.formatNumber(count)} ${this.pluralize(count, config.singular)}
          </a>
        `
      })
      .join("")

    this.jumpChipsTarget.innerHTML = chips
    this.jumpChipsTarget.classList.toggle("is-hidden", chips.trim() === "")
  }

  hideAllSections() {
    Object.keys(SECTION_CONFIG).forEach((type) => {
      this[`${type}SectionTarget`].hidden = true
    })
  }

  showStatus(html) {
    this.statusTarget.hidden = false
    this.statusTarget.innerHTML = `<p>${html}</p>`
  }

  hideStatus() {
    this.statusTarget.hidden = true
    this.statusTarget.innerHTML = ""
  }

  renderRecord(type, record) {
    switch (type) {
      case "illustrations":
        return this.renderIllustration(record)
      case "novels":
        return this.renderNovel(record)
      case "editions":
        return this.renderEdition(record)
      case "illustrators":
        return this.renderIllustrator(record)
      default:
        return ""
    }
  }

  renderIllustration(record) {
    const title = this.metaValue(record, "title") || "Untitled illustration"
    const novelName = this.metaValue(record, "novel_name")
    const illustratorName = this.metaValue(record, "illustrator_name")
    const image = this.metaValue(record, "image")

    return `
      <a class="search-card search-card--illustration" href="${this.escapeAttribute(record.url)}">
        ${this.renderImage(image, title)}
        <div class="search-card-body">
          <p class="search-card-kicker">Illustration</p>
          <h3>${this.escapeHtml(title)}</h3>
          ${novelName ? `<p><strong>${this.escapeHtml(novelName)}</strong></p>` : ""}
          ${illustratorName ? `<p>${this.escapeHtml(illustratorName)}</p>` : ""}
        </div>
      </a>
    `
  }

  renderNovel(record) {
    const title = this.metaValue(record, "novel_name") || this.metaValue(record, "title") || "Untitled novel"
    const image = this.metaValue(record, "image")
    const summary = this.metaValue(record, "summary")

    return `
      <a class="search-card" href="${this.escapeAttribute(record.url)}">
        ${this.renderImage(image, title)}
        <div class="search-card-body">
          <p class="search-card-kicker">Novel</p>
          <h3>${this.escapeHtml(title)}</h3>
          ${summary ? `<p class="search-card-excerpt">${this.escapeHtml(summary)}</p>` : ""}
        </div>
      </a>
    `
  }

  renderEdition(record) {
    const title = this.metaValue(record, "edition_title") || this.metaValue(record, "title") || "Untitled edition"
    const novelName = this.metaValue(record, "novel_name")
    const citation = this.metaValue(record, "publication_citation") || this.metaValue(record, "summary")

    return `
      <a class="search-list-item" href="${this.escapeAttribute(record.url)}">
        <div>
          <p class="search-card-kicker">Edition</p>
          <h3>${this.escapeHtml(title)}</h3>
          ${novelName ? `<p><strong>${this.escapeHtml(novelName)}</strong></p>` : ""}
          ${citation ? `<p>${this.escapeHtml(citation)}</p>` : ""}
        </div>
      </a>
    `
  }

  renderIllustrator(record) {
    const title = this.metaValue(record, "illustrator_name") || this.metaValue(record, "title") || "Untitled illustrator"
    const summary = this.metaValue(record, "summary")

    return `
      <a class="search-list-item" href="${this.escapeAttribute(record.url)}">
        <div>
          <p class="search-card-kicker">Illustrator</p>
          <h3>${this.escapeHtml(title)}</h3>
          ${summary ? `<p>${this.escapeHtml(summary)}</p>` : ""}
        </div>
      </a>
    `
  }

  renderImage(source, alt) {
    if (!source) return ""

    return `
      <div class="search-card-image-frame">
        <img class="search-card-image" src="${this.escapeAttribute(source)}" alt="${this.escapeAttribute(alt)}" loading="lazy" decoding="async">
      </div>
    `
  }

  metaValue(record, key) {
    return record.meta?.[key] || ""
  }

  formatNumber(value) {
    return Number(value || 0).toLocaleString()
  }

  pluralize(count, singular) {
    return count === 1 ? singular : `${singular}s`
  }

  escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }

  escapeAttribute(value) {
    return this.escapeHtml(value)
  }
};
