namespace :images do
  desc "Attach images directly from DB URL fields and legacy filename columns"
  task attach_from_db: :environment do
    require "httparty"
    require "stringio"
    require "uri"

    dry_run = truthy_env?(ENV["DRY_RUN"])
    force = truthy_env?(ENV["FORCE"])
    only = ENV["ONLY"].to_s.downcase

    attach_illustrations = only.blank? || only == "all" || only == "illustrations"
    attach_editions = only.blank? || only == "all" || only == "editions"

    stats = {
      attached: 0,
      skipped: 0,
      missing_url: 0,
      failed: 0
    }

    puts "=" * 80
    puts "ATTACHING IMAGES FROM DB URL FIELDS"
    puts "=" * 80
    puts "Dry run: #{dry_run}"
    puts "Force reattach: #{force}"
    puts "Scope: #{only.presence || 'all'}"

    if attach_illustrations
      puts "\n" + "-" * 80
      puts "ILLUSTRATIONS (image_url)"
      puts "-" * 80
      attach_records_from_db_url(
        scope: Illustration.where.not(image_url: [nil, ""]).or(Illustration.where.not(image_file_name: [nil, ""])),
        attachment_name: :image,
        reference_method: :legacy_image_reference,
        label: "Illustration",
        dry_run: dry_run,
        force: force,
        stats: stats
      )
    end

    if attach_editions
      puts "\n" + "-" * 80
      puts "EDITIONS (cover_url)"
      puts "-" * 80
      attach_records_from_db_url(
        scope: Edition.where.not(cover_url: [nil, ""]).or(Edition.where.not(image_file_name: [nil, ""])),
        attachment_name: :cover_image,
        reference_method: :legacy_cover_reference,
        label: "Edition",
        dry_run: dry_run,
        force: force,
        stats: stats
      )
    end

    puts "\n" + "=" * 80
    puts "SUMMARY"
    puts "=" * 80
    puts "Attached: #{stats[:attached]}"
    puts "Skipped: #{stats[:skipped]}"
    puts "Missing URL: #{stats[:missing_url]}"
    puts "Failed: #{stats[:failed]}"
    puts "=" * 80
  end

  def attach_records_from_db_url(scope:, attachment_name:, reference_method:, label:, dry_run:, force:, stats:)
    total = scope.count

    scope.find_each.with_index(1) do |record, index|
      attachment = record.public_send(attachment_name)
      raw_value = record.public_send(reference_method)

      if attachment.attached? && !force
        puts "[#{index}/#{total}] #{label} ##{record.id} - skipped (already attached)"
        stats[:skipped] += 1
        next
      end

      candidate_urls =
        if record.respond_to?(:cover_source_candidates)
          record.cover_source_candidates
        elsif record.respond_to?(:image_source_candidates)
          record.image_source_candidates
        else
          DbImageUrlResolver.new(raw_value).candidates
        end

      if candidate_urls.empty?
        puts "[#{index}/#{total}] #{label} ##{record.id} - missing image reference"
        stats[:missing_url] += 1
        next
      end

      primary_url = candidate_urls.first

      if dry_run
        puts "[#{index}/#{total}] #{label} ##{record.id} - would attach from #{primary_url}"
        next
      end

      download = fetch_first_available(candidate_urls, raw_value)
      unless download
        puts "[#{index}/#{total}] #{label} ##{record.id} - failed to download from all candidates"
        stats[:failed] += 1
        next
      end

      attachment.purge if force && attachment.attached?

      attachment.attach(
        io: StringIO.new(download[:body]),
        filename: download[:filename],
        content_type: download[:content_type]
      )

      if attachment.attached?
        puts "[#{index}/#{total}] #{label} ##{record.id} - attached (#{download[:source_url]})"
        stats[:attached] += 1
      else
        puts "[#{index}/#{total}] #{label} ##{record.id} - failed to persist attachment"
        stats[:failed] += 1
      end
    rescue => e
      puts "[#{index}/#{total}] #{label} ##{record.id} - error: #{e.message}"
      stats[:failed] += 1
    end
  end

  def fetch_first_available(urls, raw_value)
    urls.each do |url|
      response = HTTParty.get(url, timeout: 30, follow_redirects: true)
      next unless response.success?

      body = response.body
      next if body.blank?

      content_type = response.headers["content-type"].to_s.split(";").first.presence || "image/jpeg"
      filename = inferred_filename(raw_value, url)
      return { body: body, filename: filename, content_type: content_type, source_url: url }
    rescue => _e
      next
    end

    nil
  end

  def inferred_filename(raw_value, url)
    raw_basename = File.basename(raw_value.to_s)
    return raw_basename if raw_basename.present? && raw_basename !~ %r{\Ahttps?://}i && raw_basename != "/"

    uri = URI.parse(url)
    path_basename = File.basename(uri.path)
    return path_basename if path_basename.present? && path_basename != "/"

    "image_#{Time.now.to_i}.jpg"
  rescue URI::InvalidURIError
    "image_#{Time.now.to_i}.jpg"
  end

  def truthy_env?(value)
    %w[1 true yes y].include?(value.to_s.downcase)
  end
end
