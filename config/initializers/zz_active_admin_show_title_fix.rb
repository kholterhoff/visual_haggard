Rails.application.config.to_prepare do
  ActiveAdmin::Views::Pages::Show.class_eval do
    protected

    # ActiveAdmin's default show title comes from `display_name`, which is already
    # HTML-escaped for use in body content. We still want to escape tags and
    # ampersands, but leaving apostrophes/quotes as plain text avoids literal
    # entities appearing in browser tabs when client-side code reuses the title.
    def default_title
      title = render_in_context(resource, display_name_method_for(resource))
      return normalized_admin_title(title) if title.to_s.strip.present?

      normalized_admin_title(
        render_in_context(resource, ActiveAdmin::ViewHelpers::DisplayHelper::DISPLAY_NAME_FALLBACK)
      )
    end

    def normalized_admin_title(value)
      ERB::Util.html_escape_once(value.to_s)
               .gsub("&#39;", "'")
               .gsub("&quot;", "\"")
               .html_safe
    end
  end
end
