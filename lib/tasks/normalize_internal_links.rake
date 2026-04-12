require "uri"

namespace :data do
  desc "Rewrite stored visualhaggard.org href/src links to relative app paths"
  task normalize_internal_links: :environment do
    targets = {
      Novel => %i[description],
      Illustrator => %i[bio],
      Illustration => %i[description],
      BlogPost => %i[content]
    }

    total_updates = 0

    targets.each do |model, fields|
      model_updates = 0

      fields.each do |field|
        next unless model.column_names.include?(field.to_s)

        model.where.not(field => [nil, ""]).find_each do |record|
          original_content = record.public_send(field).to_s
          normalized_content = normalize_internal_archive_links_in_html(original_content)
          next if normalized_content == original_content

          record.update!(field => normalized_content)
          model_updates += 1
          total_updates += 1

          puts "Updated #{model.name}##{record.id} #{field}"
        end
      end

      puts "#{model.name}: #{model_updates} record(s) updated"
    end

    puts "Total records updated: #{total_updates}"
  end

  def normalize_internal_archive_links_in_html(content)
    content.gsub(internal_archive_link_pattern) do
      attribute = Regexp.last_match[:attribute]
      quote = Regexp.last_match[:quote]
      url = Regexp.last_match[:url]

      %(#{attribute}=#{quote}#{normalize_internal_archive_url(url)}#{quote})
    end
  end

  def internal_archive_link_pattern
    /\b(?<attribute>href|src)\s*=?\s*(?<quote>["'])(?<url>https?:\/\/(?:www\.)?visualhaggard\.org[^"'<>]*)\k<quote>/i
  end

  def normalize_internal_archive_url(url)
    uri = URI.parse(url.to_s)
    return url if uri.host.blank?

    normalized = uri.path.presence || "/"
    normalized += "?#{uri.query}" if uri.query.present?
    normalized += "##{uri.fragment}" if uri.fragment.present?
    normalized
  rescue URI::InvalidURIError
    url
  end
end
