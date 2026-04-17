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
  illustrators: {
    filter: "illustrator",
    singular: "illustrator",
    batchSize: 12,
    sectionId: "pagefind-search-illustrators",
    label: "Illustrator"
  }
}

const ILLUSTRATION_GROUPING_CONFIG = {
  novel: {
    tabLabel: "By novel",
    eyebrow: "Novel"
  },
  edition: {
    tabLabel: "By edition",
    eyebrow: "Edition"
  },
  illustrator: {
    tabLabel: "By illustrator",
    eyebrow: "Illustrator"
  }
}

export default class extends Controller {
  static targets = [
    "fallback",
    "shell",
    "status",
    "announcer",
    "jumpChips",
    "illustrationsSection",
    "illustrationsCount",
    "illustrationsResults",
    "illustrationsMore",
    "novelsSection",
    "novelsCount",
    "novelsResults",
    "novelsMore",
    "illustratorsSection",
    "illustratorsCount",
    "illustratorsResults",
    "illustratorsMore"
  ]

  static values = {
    query: String
  }

  connect() {
    this.query = ""
    this.resultHandles = {}
    this.renderedCounts = {}
    this.renderedRecords = {}
    this.illustrationGrouping = "novel"
    this.pagefindAvailability = undefined
    this.pagefindAvailabilityPromise = null
    this.handleLocationChange = this.refresh.bind(this)

    document.addEventListener("turbo:load", this.handleLocationChange)
    window.addEventListener("popstate", this.handleLocationChange)

    this.refresh()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.handleLocationChange)
    window.removeEventListener("popstate", this.handleLocationChange)
  }

  async initializeSearch() {
    this.resultHandles = {}
    this.renderedCounts = {}
    this.renderedRecords = {}

    const pagefindAvailable = await this.pagefindIndexAvailable()
    if (!pagefindAvailable) {
      this.showUnavailableState()
      return
    }

    this.activateShell()
    this.setBusy(true)
    this.hideAllSections()
    this.showStatus(`Searching the archive for <strong>${this.escapeHtml(this.query)}</strong>…`)
    this.announce(`Searching the archive for ${this.query}.`)

    let pagefind

    try {
      pagefind = await import("/pagefind/pagefind.js")
    } catch (error) {
      console.error("Pagefind could not be loaded", error)
      this.setBusy(false)

      if (this.query !== this.queryValue) {
        this.shellTarget.hidden = false
        this.showStatus("Static search is unavailable right now. Rebuild the Pagefind index before previewing the published archive.")
        this.announce("Static search is unavailable right now.")
      }
      return
    }

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
        this.setBusy(false)
        this.announce(`No results were found for ${this.query}.`)
        return
      }

      this.hideStatus()
      await Promise.all(Object.keys(SECTION_CONFIG).map((key) => this.renderNextBatch(key, { reset: true })))
      this.setBusy(false)
      this.announceResults(totalMatches)
    } catch (error) {
      console.error("Pagefind search failed", error)
      this.hideAllSections()
      this.setBusy(false)
      this.showStatus("Static search is unavailable right now. Rebuild the Pagefind index before previewing the published archive.")
      this.announce("Static search is unavailable right now.")
    }
  }

  async loadMore(event) {
    const type = event.params.type
    if (!SECTION_CONFIG[type]) return

    const beforeCount = this.renderedCounts[type] || 0
    await this.renderNextBatch(type)

    const loadedCount = (this.renderedCounts[type] || 0) - beforeCount
    if (loadedCount > 0) {
      this.announce(`Loaded ${this.formatNumber(loadedCount)} more ${this.pluralize(loadedCount, SECTION_CONFIG[type].singular)}.`)
    }
  }

  activateShell() {
    this.shellTarget.hidden = false
    this.fallbackTarget.hidden = true
  }

  showFallbackResults() {
    this.shellTarget.hidden = true
    this.fallbackTarget.hidden = false
    this.hideAllSections()
    this.hideStatus()
    this.setBusy(false)
  }

  showUnavailableState() {
    this.setBusy(false)
    this.hideAllSections()

    if (this.query) {
      this.activateShell()
      this.showStatus("Search is temporarily unavailable right now. Rebuild the Pagefind index before publishing the archive.")
      this.announce("Search is temporarily unavailable right now.")
      return
    }

    this.showFallbackResults()
  }

  refresh() {
    const nextQuery = this.currentQuery()
    this.syncSearchFields(nextQuery)

    if (!nextQuery) {
      this.query = ""
      this.resultHandles = {}
      this.renderedCounts = {}
      this.renderedRecords = {}
      this.shellTarget.hidden = true
      this.fallbackTarget.hidden = false
      this.setBusy(false)
      this.hideAllSections()
      this.hideStatus()
      this.announce("")
      this.jumpChipsTarget.innerHTML = ""
      this.jumpChipsTarget.classList.add("is-hidden")
      return
    }

    if (nextQuery === this.query && !this.shellTarget.hidden) return

    this.query = nextQuery
    this.initializeSearch()
  }

  syncSearchFields(query) {
    document.querySelectorAll('input[name="search"]').forEach((field) => {
      field.value = query
    })
  }

  currentQuery() {
    const params = new URLSearchParams(window.location.search)
    return (params.get("search") || params.get("q") || this.queryValue || "").trim()
  }

  async pagefindIndexAvailable() {
    if (typeof this.pagefindAvailability === "boolean") return this.pagefindAvailability
    if (this.pagefindAvailabilityPromise) return this.pagefindAvailabilityPromise

    const controller = new AbortController()
    const timeoutId = window.setTimeout(() => controller.abort(), 3000)

    this.pagefindAvailabilityPromise = fetch("/pagefind/pagefind-entry.json", {
      method: "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
      signal: controller.signal
    })
      .then((response) => response.ok)
      .catch(() => false)
      .then((available) => {
        this.pagefindAvailability = available
        return available
      })
      .finally(() => {
        window.clearTimeout(timeoutId)
        this.pagefindAvailabilityPromise = null
      })

    return this.pagefindAvailabilityPromise
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
      this.renderedRecords[type] = []
      return
    }

    if (reset) {
      resultsTarget.innerHTML = ""
      this.renderedCounts[type] = 0
    }

    const alreadyRendered = this.renderedCounts[type] || 0
    const nextHandles = handles.slice(alreadyRendered, alreadyRendered + config.batchSize)
    const records = await Promise.all(nextHandles.map((handle) => handle.data()))
    const accumulatedRecords = reset ? records : (this.renderedRecords[type] || []).concat(records)
    this.renderedRecords[type] = accumulatedRecords

    if (type === "illustrations") {
      resultsTarget.innerHTML = this.renderIllustrationGroupings(accumulatedRecords)
    } else {
      resultsTarget.insertAdjacentHTML(
        "beforeend",
        records.map((record) => this.renderRecord(type, record)).join("")
      )
    }

    this.renderedCounts[type] = alreadyRendered + records.length
    sectionTarget.hidden = false
    moreTarget.hidden = this.renderedCounts[type] >= handles.length
  }

  switchIllustrationGrouping(event) {
    const grouping = event.params.grouping
    if (!grouping) return

    const root = event.currentTarget.closest("[data-search-illustration-grouping]")
    if (!root) return

    this.illustrationGrouping = grouping
    this.applyIllustrationGrouping(root, grouping)
  }

  renderJumpChips() {
    const chipTypes = ["illustrations", "novels", "illustrators"]
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

  announce(message) {
    if (!this.hasAnnouncerTarget) return

    this.announcerTarget.textContent = message
  }

  announceResults(totalMatches) {
    const sectionSummaries = Object.entries(SECTION_CONFIG)
      .filter(([type]) => (this.resultHandles[type] || []).length > 0)
      .map(([type, config]) => `${this.formatNumber(this.resultHandles[type].length)} ${this.pluralize(this.resultHandles[type].length, config.singular)}`)

    this.announce(`Found ${this.formatNumber(totalMatches)} results for ${this.query}. ${sectionSummaries.join(", ")}.`)
  }

  setBusy(isBusy) {
    this.shellTarget.setAttribute("aria-busy", isBusy ? "true" : "false")
  }

  renderRecord(type, record) {
    switch (type) {
      case "illustrations":
        return this.renderIllustration(record)
      case "novels":
        return this.renderNovel(record)
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
    const publicationCitation = this.metaValue(record, "publication_citation")
    const image = this.metaValue(record, "image")
    const renderedTitle = novelName && title === novelName ? this.renderWorkTitle(title) : this.escapeHtml(title)

    return `
      <a class="search-card search-card--illustration" href="${this.escapeAttribute(record.url)}">
        ${this.renderImage(image, title)}
        <div class="search-card-body">
          <p class="search-card-kicker">Illustration</p>
          <h3>${renderedTitle}</h3>
          ${novelName ? `<p><strong>${this.renderWorkTitle(novelName)}</strong></p>` : ""}
          ${illustratorName ? `<p>${this.escapeHtml(illustratorName)}</p>` : ""}
          ${publicationCitation ? `<p class="search-card-citation">${this.escapeHtml(publicationCitation)}</p>` : ""}
        </div>
      </a>
    `
  }

  renderIllustrationGroupings(records) {
    const groupingData = this.buildIllustrationGroupingData(records)
    const renderedGroupings = groupingData.visibleGroupings.length ? groupingData.visibleGroupings : [groupingData.activeGrouping]
    const rootId = "pagefind-search-illustrations-grouping"
    const showTabs = groupingData.visibleGroupings.length > 1

    this.illustrationGrouping = groupingData.activeGrouping

    return `
      <div class="search-illustration-browser" data-search-illustration-grouping data-active-grouping="${this.escapeAttribute(groupingData.activeGrouping)}">
        ${showTabs ? this.renderIllustrationGroupingTabs(groupingData.visibleGroupings, groupingData.activeGrouping, rootId) : ""}
        ${renderedGroupings.map((grouping) => this.renderIllustrationGroupingPanel(grouping, groupingData.groups[grouping] || [], groupingData.activeGrouping, rootId, showTabs)).join("")}
      </div>
    `
  }

  buildIllustrationGroupingData(records) {
    const groupMaps = {
      novel: new Map(),
      edition: new Map(),
      illustrator: new Map()
    }

    records.forEach((record) => {
      const novelName = this.metaValue(record, "novel_name") || "Unknown novel"
      const editionTitle = this.metaValue(record, "edition_title") || "Untitled edition"
      const illustratorName = this.metaValue(record, "illustrator_name") || "Unknown illustrator"
      const publicationCitation = this.metaValue(record, "publication_citation")

      this.pushIllustrationGroup(groupMaps.novel, `novel:${novelName}`, { novelName }, record)
      this.pushIllustrationGroup(groupMaps.edition, `edition:${novelName}:${editionTitle}:${publicationCitation}`, { title: editionTitle, novelName }, record)
      this.pushIllustrationGroup(groupMaps.illustrator, `illustrator:${illustratorName}`, { title: illustratorName }, record)
    })

    const groups = {
      novel: Array.from(groupMaps.novel.values()),
      edition: Array.from(groupMaps.edition.values()),
      illustrator: Array.from(groupMaps.illustrator.values())
    }
    const visibleGroupings = Object.keys(ILLUSTRATION_GROUPING_CONFIG).filter((grouping) => groups[grouping].length > 1)

    const activeGrouping =
      visibleGroupings.includes(this.illustrationGrouping) ? this.illustrationGrouping :
      (visibleGroupings.includes("novel") || visibleGroupings.length === 0) ? "novel" :
      visibleGroupings[0]

    return {
      groups,
      visibleGroupings,
      activeGrouping
    }
  }

  pushIllustrationGroup(groupMap, key, attributes, record) {
    if (!groupMap.has(key)) {
      groupMap.set(key, { ...attributes, records: [] })
    }

    groupMap.get(key).records.push(record)
  }

  renderIllustrationGroupingTabs(groupings, activeGrouping, rootId) {
    return `
      <div class="search-group-tabs" role="tablist" aria-label="Group illustration results">
        ${groupings.map((grouping) => this.renderIllustrationGroupingTab(grouping, activeGrouping, rootId)).join("")}
      </div>
    `
  }

  renderIllustrationGroupingTab(grouping, activeGrouping, rootId) {
    const config = ILLUSTRATION_GROUPING_CONFIG[grouping]
    const active = grouping === activeGrouping

    return `
      <button
        type="button"
        class="search-group-tab${active ? " is-active" : ""}"
        id="${this.escapeAttribute(`${rootId}-${grouping}-tab`)}"
        role="tab"
        aria-selected="${active ? "true" : "false"}"
        aria-controls="${this.escapeAttribute(`${rootId}-${grouping}-panel`)}"
        tabindex="${active ? "0" : "-1"}"
        data-action="pagefind-search#switchIllustrationGrouping"
        data-pagefind-search-grouping-param="${this.escapeAttribute(grouping)}"
        data-search-illustration-tab="${this.escapeAttribute(grouping)}"
      >
        ${this.escapeHtml(config.tabLabel)}
      </button>
    `
  }

  renderIllustrationGroupingPanel(grouping, groups, activeGrouping, rootId, showTabs) {
    const active = grouping === activeGrouping
    const accessibilityLabel = showTabs ?
      `aria-labelledby="${this.escapeAttribute(`${rootId}-${grouping}-tab`)}"` :
      `aria-label="Illustration results grouped ${this.escapeAttribute(ILLUSTRATION_GROUPING_CONFIG[grouping].tabLabel.toLowerCase())}"`

    return `
      <div
        class="search-illustration-group-panel"
        id="${this.escapeAttribute(`${rootId}-${grouping}-panel`)}"
        role="tabpanel"
        ${accessibilityLabel}
        data-search-illustration-panel="${this.escapeAttribute(grouping)}"
        ${active ? "" : "hidden"}
      >
        ${groups.map((group) => this.renderIllustrationGroup(grouping, group)).join("")}
      </div>
    `
  }

  renderIllustrationGroup(grouping, group) {
    const config = ILLUSTRATION_GROUPING_CONFIG[grouping]
    const groupHeading = this.renderIllustrationGroupHeading(grouping, group)
    const groupMeta = this.renderIllustrationGroupMeta(grouping, group)

    return `
      <section class="search-illustration-group">
        <div class="section-heading search-illustration-group-heading">
          <div>
            <p class="page-eyebrow">${this.escapeHtml(config.eyebrow)}</p>
            ${groupHeading}
            ${groupMeta}
          </div>
          <p class="search-illustration-group-count">
            ${this.formatNumber(group.records.length)} ${this.pluralize(group.records.length, "illustration")}
          </p>
        </div>
        <div class="search-card-grid search-card-grid--illustrations">
          ${group.records.map((record) => this.renderIllustration(record)).join("")}
        </div>
      </section>
    `
  }

  renderIllustrationGroupHeading(grouping, group) {
    switch (grouping) {
      case "novel":
        return `<h3>Illustrations from ${this.renderWorkTitle(group.novelName)}</h3>`
      case "edition":
        return `<h3>${this.escapeHtml(group.title)}</h3>`
      case "illustrator":
        return `<h3>Illustrations by ${this.escapeHtml(group.title)}</h3>`
      default:
        return ""
    }
  }

  renderIllustrationGroupMeta(grouping, group) {
    if (grouping !== "edition" || !group.novelName) return ""

    return `<p class="search-illustration-group-meta">${this.renderWorkTitle(group.novelName)}</p>`
  }

  applyIllustrationGrouping(root, grouping) {
    root.dataset.activeGrouping = grouping

    root.querySelectorAll("[data-search-illustration-tab]").forEach((tab) => {
      const active = tab.dataset.searchIllustrationTab === grouping
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
      tab.setAttribute("tabindex", active ? "0" : "-1")
    })

    root.querySelectorAll("[data-search-illustration-panel]").forEach((panel) => {
      panel.hidden = panel.dataset.searchIllustrationPanel !== grouping
    })
  }

  renderWorkTitle(value) {
    return `<cite class="work-title">${this.escapeHtml(value)}</cite>`
  }

  renderNovel(record) {
    const title = this.metaValue(record, "novel_name") || this.metaValue(record, "title") || "Untitled novel"
    const image = this.metaValue(record, "image")
    const summaryHtml = this.metaValue(record, "summary_html")
    const summary = this.metaValue(record, "summary")

    return `
      <a class="search-card" href="${this.escapeAttribute(record.url)}">
        ${this.renderImage(image, title)}
        <div class="search-card-body">
          <p class="search-card-kicker">Novel</p>
          <h3>${this.renderWorkTitle(title)}</h3>
          ${this.renderFormattedExcerpt(summaryHtml, summary)}
        </div>
      </a>
    `
  }

  renderIllustrator(record) {
    const title = this.metaValue(record, "illustrator_name") || this.metaValue(record, "title") || "Untitled illustrator"
    const summaryHtml = this.metaValue(record, "summary_html")
    const summary = this.metaValue(record, "summary")

    return `
      <a class="search-card search-card--illustrator" href="${this.escapeAttribute(record.url)}">
        <div class="search-card-body">
          <p class="search-card-kicker">Illustrator</p>
          <h3>${this.escapeHtml(title)}</h3>
          ${this.renderFormattedExcerpt(summaryHtml, summary)}
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

  renderFormattedExcerpt(summaryHtml, summary) {
    const formatted = this.sanitizeInlineHtml(summaryHtml)
    if (formatted) {
      return `<p class="search-card-excerpt">${formatted}</p>`
    }

    if (summary) {
      return `<p class="search-card-excerpt">${this.escapeHtml(summary)}</p>`
    }

    return ""
  }

  metaValue(record, key) {
    return this.decodeHtmlEntities(record.meta?.[key] || "")
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

  decodeHtmlEntities(value) {
    const normalized = String(value || "")
    if (!normalized.includes("&")) return normalized

    const textarea = document.createElement("textarea")
    textarea.innerHTML = normalized
    return textarea.value
  }

  sanitizeInlineHtml(value) {
    const normalized = String(value || "").trim()
    if (!normalized) return ""

    const template = document.createElement("template")
    template.innerHTML = normalized
    const allowedTags = new Set(["CITE", "EM", "I", "STRONG", "B", "MARK"])

    const clean = (node) => {
      Array.from(node.childNodes).forEach((child) => {
        if (child.nodeType !== Node.ELEMENT_NODE) return

        clean(child)

        if (!allowedTags.has(child.tagName)) {
          child.replaceWith(...Array.from(child.childNodes))
          return
        }

        Array.from(child.attributes).forEach((attribute) => {
          const keepWorkTitleClass =
            child.tagName === "CITE" && attribute.name === "class" && attribute.value === "work-title"

          if (!keepWorkTitleClass) {
            child.removeAttribute(attribute.name)
          }
        })
      })
    }

    clean(template.content)
    return template.innerHTML.trim()
  }
};
