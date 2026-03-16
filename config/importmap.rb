# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "photoswipe", to: "https://cdn.jsdelivr.net/npm/photoswipe@5.4.4/dist/photoswipe.esm.js"
pin "photoswipe-lightbox", to: "https://cdn.jsdelivr.net/npm/photoswipe@5.4.4/dist/photoswipe-lightbox.esm.js"
pin_all_from "app/javascript/controllers", under: "controllers"
