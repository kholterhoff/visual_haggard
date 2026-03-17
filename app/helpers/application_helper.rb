module ApplicationHelper
  LEGACY_INTERNAL_HOSTS = %w[visualhaggard.org www.visualhaggard.org].freeze

  def primary_nav_link_to(name, path, **options)
    current = current_page?(path)
    classes = [options[:class], ("is-current" if current)].compact.join(" ")
    aria_options = (options[:aria] || {}).dup
    aria_options[:current] = "page" if current

    link_to name, path, options.merge(class: classes.presence, aria: aria_options)
  end

  def normalized_simple_format(content)
    return "".html_safe if content.blank?

    rewrite_legacy_internal_urls(simple_format(content))
  end

  def plain_text_excerpt(content, length: 180)
    return if content.blank?

    text = strip_tags(content.to_s).squish
    return if text.blank?

    truncate(text, length:)
  end

  def rewrite_legacy_internal_urls(html)
    fragment = Nokogiri::HTML::DocumentFragment.parse(html.to_s)

    fragment.css("[href], [src]").each do |node|
      %w[href src].each do |attribute|
        value = node[attribute]
        next if value.blank?

        node[attribute] = normalize_legacy_internal_url(value)
      end
    end

    fragment.to_html.html_safe
  end

  def public_asset_url(source)
    return if source.blank?

    return source if source.is_a?(String)

    to_relative_url(url_for(source))
  end

  def zoomable_image_link(source, alt: nil, image_options: {}, link_options: {}, &block)
    return if source.blank?

    href = public_asset_url(source)
    merged_link_options = {
      target: "_blank",
      rel: "noopener noreferrer"
    }.merge(link_options)

    merged_link_options[:data] = (merged_link_options[:data] || {}).merge(zoomable_image: true)

    return link_to(href, merged_link_options, &block) if block_given?

    link_to href, merged_link_options do
      image_tag source, { alt:, decoding: "async" }.merge(image_options)
    end
  end

  def pagefind_record_data(meta: {}, filters: {}, body: nil)
    fragments = []

    filters.each do |name, value|
      append_pagefind_tag(fragments, :pagefind_filter, name, value)
    end

    meta.each do |name, value|
      append_pagefind_tag(fragments, :pagefind_meta, name, value)
    end

    Array(body).flatten.each do |value|
      normalized = normalize_pagefind_value(value)
      next if normalized.blank?

      fragments << content_tag(:span, normalized, class: "sr-only")
    end

    return "".html_safe if fragments.empty?

    content_tag(:div, safe_join(fragments), class: "pagefind-record-data sr-only")
  end

  def work_title(title, class_name: nil)
    classes = ["work-title", class_name].compact.join(" ")
    content_tag(:cite, title.to_s, class: classes.presence)
  end

  def linked_work_title(title, path, **options)
    link_to work_title(title), path, options
  end

  def linked_novel_title(novel, **options)
    linked_work_title(novel.name, novel_path(novel), **options)
  end

  def style_edition_citation(edition)
    fragments = ["Cover. ".html_safe, work_title(edition.novel.name), ". ".html_safe]

    if (edition_label = archive_reference_value(edition.display_title)).present?
      fragments << edition_label
      fragments << ". ".html_safe
    end

    publication_parts = []
    publication_city = archive_reference_value(edition.publication_city)
    publisher = archive_reference_value(edition.publisher)
    publication_date = archive_reference_value(edition.publication_date)

    if publication_city.present? && publisher.present?
      publication_parts << "#{publication_city}: #{publisher}"
    elsif publication_city.present? || publisher.present?
      publication_parts << publication_city.presence || publisher
    end

    publication_parts << publication_date if publication_date.present?

    if publication_parts.any?
      fragments << publication_parts.join(", ")
      fragments << ". ".html_safe
    end

    if (source = archive_reference_value(edition.source)).present?
      fragments << source
      fragments << ".".html_safe
    elsif fragments.last == ". ".html_safe
      fragments[-1] = ".".html_safe
    end

    safe_join(fragments)
  end

  private

  def archive_reference_value(value)
    normalized = value.to_s.strip
    return if normalized.blank? || %w[Unknown None].include?(normalized)

    normalized
  end

  def append_pagefind_tag(fragments, data_key, name, value)
    normalized = normalize_pagefind_value(value)
    return if normalized.blank?

    fragments << content_tag(:span, normalized, class: "sr-only", data: { data_key => name })
  end

  def normalize_pagefind_value(value)
    Array(value).flatten.compact.map(&:to_s).join(" ").squish.presence
  end

  def to_relative_url(value)
    uri = URI.parse(value.to_s)
    return value if uri.host.blank?

    normalized = uri.path.presence || "/"
    normalized += "?#{uri.query}" if uri.query.present?
    normalized += "##{uri.fragment}" if uri.fragment.present?
    normalized
  rescue URI::InvalidURIError
    value
  end

  def normalize_legacy_internal_url(value)
    uri = URI.parse(value)
    return value unless uri.is_a?(URI::HTTP)
    return value unless LEGACY_INTERNAL_HOSTS.include?(uri.host)

    normalized = uri.path.presence || "/"
    normalized += "?#{uri.query}" if uri.query.present?
    normalized += "##{uri.fragment}" if uri.fragment.present?
    normalized
  rescue URI::InvalidURIError
    value
  end
end
