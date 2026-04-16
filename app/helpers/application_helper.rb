require "cgi"

module ApplicationHelper
  LEGACY_INTERNAL_HOSTS = %w[visualhaggard.org www.visualhaggard.org].freeze
  SEARCH_EXCERPT_INLINE_TAGS = %w[cite em i strong b].freeze
  SEARCH_EXCERPT_BLOCK_TAGS = %w[p br ul ol li blockquote h2 h3 h4 div].freeze

  def primary_nav_link_to(name, path, **options)
    current = current_page?(path)
    classes = [options[:class], ("is-current" if current)].compact.join(" ")
    aria_options = (options[:aria] || {}).dup
    aria_options[:current] = "page" if current

    link_to name, path, options.merge(class: classes.presence, aria: aria_options)
  end

  def normalized_simple_format(content)
    return "".html_safe if content.blank?

    normalized_content = normalize_legacy_rich_text(content)
    return normalized_content if normalized_content_contains_block_html?(normalized_content)

    simple_format(normalized_content, {}, sanitize: false)
  end

  def plain_text_excerpt(content, length: 180)
    return if content.blank?

    text = Nokogiri::HTML::DocumentFragment.parse(CGI.unescapeHTML(content.to_s)).text.squish
    return if text.blank?

    truncate(text, length:, escape: false)
  end

  def search_excerpt_html(content, length: 180)
    return if content.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(normalize_legacy_rich_text(content))
    excerpt = Nokogiri::HTML::DocumentFragment.parse("")
    state = {
      remaining: length,
      started: false,
      last_space: true,
      truncated: false
    }

    fragment.children.each do |node|
      append_search_excerpt_node(node, excerpt, state)
      break if state[:remaining] <= 0
    end

    trim_trailing_search_excerpt_whitespace(excerpt)
    return if excerpt.children.empty?

    excerpt.add_child(Nokogiri::XML::Text.new("...", excerpt.document)) if state[:truncated]
    excerpt.to_html.html_safe
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
      normalized = normalize_pagefind_body(value)
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

  def novel_work_title(novel, short: false, class_name: nil)
    work_title(short ? novel.short_title : novel.long_title, class_name:)
  end

  def linked_work_title(title, path, **options)
    link_to work_title(title), path, options
  end

  def linked_novel_title(novel, short: false, **options)
    linked_work_title(short ? novel.short_title : novel.long_title, novel_path(novel), **options)
  end

  def condensed_edition_label(edition, novel: nil)
    label = edition&.display_title.to_s.strip
    return if label.blank?
    return label if novel.blank?

    bracketed_titles = novel.long_title.to_s.scan(/\[([^\]]+)\]/).flatten
    candidate_titles = [novel.long_title, novel.short_title, *bracketed_titles]
                      .map { |title| title.to_s.strip.presence }
                      .compact
                      .uniq
                      .sort_by { |title| -title.length }

    candidate_titles.each do |title|
      return if label.casecmp?(title)

      shortened = label.sub(/\A#{Regexp.escape(title)}(?:\s*[-,:;]\s*|\s+)/i, "").strip
      return shortened if shortened.present? && shortened.casecmp?(label) != 0
    end

    label
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

  def normalize_legacy_rich_text(content)
    fragment = Nokogiri::HTML::DocumentFragment.parse(CGI.unescapeHTML(content.to_s))

    normalize_legacy_inline_formatting(fragment)
    rewrite_legacy_internal_urls_in_fragment(fragment)
    wrap_loose_top_level_inline_content(fragment)

    sanitize(
      fragment.to_html,
      tags: %w[p br em i strong b cite a ul ol li blockquote h2 h3 h4],
      attributes: %w[href title target rel]
    )
  end

  def normalized_content_contains_block_html?(content)
    content.to_s.match?(%r{<(?:p|br|ul|ol|li|blockquote|h2|h3|h4)\b}i)
  end

  def wrap_loose_top_level_inline_content(fragment)
    buffer = []

    fragment.children.to_a.each do |node|
      if top_level_block_node?(node)
        flush_loose_top_level_buffer(fragment, buffer, before: node)
      else
        buffer << node
      end
    end

    flush_loose_top_level_buffer(fragment, buffer)
  end

  def top_level_block_node?(node)
    node.element? && %w[p ul ol li blockquote h2 h3 h4].include?(node.name)
  end

  def flush_loose_top_level_buffer(fragment, buffer, before: nil)
    nodes = buffer.shift(buffer.length)
    return if nodes.empty?

    meaningful_nodes = nodes.reject { |node| node.text? && node.text.strip.empty? }

    if meaningful_nodes.empty?
      nodes.each(&:unlink)
      return
    end

    paragraph = Nokogiri::XML::Node.new("p", fragment.document)

    nodes.each do |node|
      if node.text? && node.text.strip.empty?
        node.unlink
      else
        paragraph.add_child(node.unlink)
      end
    end

    if before.present?
      before.add_previous_sibling(paragraph)
    else
      fragment.add_child(paragraph)
    end
  end

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
    Array(value).flatten.compact.map { |entry| CGI.unescapeHTML(entry.to_s) }.join(" ").squish.presence
  end

  def normalize_pagefind_body(value)
    normalized = normalize_pagefind_value(value)
    return if normalized.blank?

    Nokogiri::HTML::DocumentFragment.parse(normalized).text.squish.presence
  end

  def append_search_excerpt_node(node, parent, state)
    return if state[:remaining] <= 0

    if node.text?
      append_search_excerpt_text(node.text, parent, state)
      return
    end

    return unless node.element?

    if search_excerpt_block_tag?(node.name) && state[:started]
      append_search_excerpt_text(" ", parent, state)
    end

    if search_excerpt_inline_tag?(node.name)
      child = Nokogiri::XML::Node.new(node.name, parent.document)
      if node.name == "cite"
        child["class"] = "work-title"
      end

      node.children.each do |nested|
        append_search_excerpt_node(nested, child, state)
        break if state[:remaining] <= 0
      end

      trim_trailing_search_excerpt_whitespace(child)
      parent.add_child(child) if child.children.any?
    else
      node.children.each do |nested|
        append_search_excerpt_node(nested, parent, state)
        break if state[:remaining] <= 0
      end
    end

    if search_excerpt_block_tag?(node.name) && state[:started]
      append_search_excerpt_text(" ", parent, state)
    end
  end

  def append_search_excerpt_text(text, parent, state)
    normalized = text.to_s.gsub(/\s+/, " ")
    normalized = normalized.lstrip if state[:last_space]
    return if normalized.blank?

    excerpt = if normalized.length > state[:remaining]
      state[:truncated] = true
      search_excerpt_boundary(normalized, state[:remaining])
    else
      normalized
    end

    excerpt = excerpt.rstrip if state[:truncated]
    return if excerpt.blank?

    parent.add_child(Nokogiri::XML::Text.new(excerpt, parent.document))
    state[:remaining] -= excerpt.length
    state[:started] = true
    state[:last_space] = excerpt.end_with?(" ")
  end

  def search_excerpt_boundary(text, remaining)
    return text if text.length <= remaining
    return text[0, remaining] if remaining <= 12

    boundary = text.rindex(" ", remaining)
    boundary = nil if boundary.to_i < (remaining * 0.55)

    (boundary ? text[0...boundary] : text[0, remaining]).to_s
  end

  def search_excerpt_inline_tag?(name)
    SEARCH_EXCERPT_INLINE_TAGS.include?(name.to_s.downcase)
  end

  def search_excerpt_block_tag?(name)
    SEARCH_EXCERPT_BLOCK_TAGS.include?(name.to_s.downcase)
  end

  def trim_trailing_search_excerpt_whitespace(fragment)
    last_text_node = fragment.children.reverse.find(&:text?)
    return unless last_text_node

    last_text_node.content = last_text_node.text.rstrip
    last_text_node.remove if last_text_node.text.empty?
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

  def rewrite_legacy_internal_urls_in_fragment(fragment)
    fragment.css("[href], [src]").each do |node|
      %w[href src].each do |attribute|
        value = node[attribute]
        next if value.blank?

        node[attribute] = normalize_legacy_internal_url(value)
      end
    end
  end

  def normalize_legacy_inline_formatting(fragment)
    fragment.css("span").each do |node|
      style = node["style"].to_s.downcase
      classes = node["class"].to_s.downcase.split(/\s+/)
      next unless style.include?("font-style:italic") || style.include?("font-style: italic") || classes.include?("italic") || classes.include?("italics")

      node.name = "em"
      node.remove_attribute("style")
      node.remove_attribute("class")
    end
  end
end
