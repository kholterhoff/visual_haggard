import { Controller } from "@hotwired/stimulus"
import PhotoSwipeLightbox from "photoswipe-lightbox"

export default class extends Controller {
  connect() {
    this.zoomableItems = Array.from(
      this.element.querySelectorAll("a[data-zoomable-image]")
    )

    if (this.zoomableItems.length === 0) return

    this.cleanupCallbacks = []
    this.zoomableItems.forEach((link) => {
      const image = link.querySelector("img")
      if (!image) return

      this.syncDimensionsFor(link, image)

      if (!image.complete) {
        const onLoad = () => this.syncDimensionsFor(link, image)
        image.addEventListener("load", onLoad)
        this.cleanupCallbacks.push(() => image.removeEventListener("load", onLoad))
      }
    })

    this.lightbox = new PhotoSwipeLightbox({
      gallery: this.element,
      children: "a[data-zoomable-image]",
      pswpModule: () => import("photoswipe"),
      initialZoomLevel: "fit",
      secondaryZoomLevel: 2.5,
      maxZoomLevel: 4
    })

    this.lightbox.init()
  }

  disconnect() {
    this.cleanupCallbacks?.forEach((callback) => callback())
    this.cleanupCallbacks = []

    if (this.lightbox) {
      this.lightbox.destroy()
      this.lightbox = null
    }
  }

  syncDimensionsFor(link, image) {
    const width = image.naturalWidth || image.clientWidth
    const height = image.naturalHeight || image.clientHeight

    if (width > 0 && height > 0) {
      link.dataset.pswpWidth = width
      link.dataset.pswpHeight = height
    }
  }
}
