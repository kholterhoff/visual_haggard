//= require active_admin/base

(function() {
  function syncActiveAdminDocumentTitle() {
    var pageTitle = document.getElementById("page_title");

    if (pageTitle && pageTitle.textContent.trim().length > 0) {
      document.title = pageTitle.textContent.trim() + " | Visual Haggard";
    }
  }

  document.addEventListener("DOMContentLoaded", syncActiveAdminDocumentTitle);
  document.addEventListener("page:load", syncActiveAdminDocumentTitle);
  document.addEventListener("turbolinks:load", syncActiveAdminDocumentTitle);
})();
