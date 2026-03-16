class DbImageUrlResolver
  LEGACY_HOST = "http://www.visualhaggard.org".freeze
  LEGACY_S3_ROOT = "https://s3-us-west-2.amazonaws.com/haggard".freeze
  WAYBACK_TIMESTAMPS = %w[20220815220555 20220815210913].freeze

  def initialize(raw_value)
    @raw_value = raw_value.to_s.strip
  end

  def candidates
    return [] if @raw_value.blank?

    candidate_source_urls.flat_map { |url| [url] + wayback_variants(url) }.uniq
  end

  def preferred_public_url
    return if @raw_value.blank?

    if filename_reference?
      s3_bucket_url
    else
      source_url = normalize_source_url(@raw_value)
      archive_url = wayback_variants(source_url).first

      if legacy_visual_haggard_reference?
        archive_url || source_url
      else
        source_url
      end
    end
  end

  private

  def candidate_source_urls
    return [s3_bucket_url, legacy_image_url].compact.uniq if filename_reference?

    [normalize_source_url(@raw_value)]
  end

  def legacy_visual_haggard_reference?
    !@raw_value.match?(%r{\Ahttps?://}i) ||
      @raw_value.include?("visualhaggard.org") ||
      @raw_value.start_with?("//")
  end

  def normalize_source_url(value)
    return value if value.match?(%r{\Ahttps?://}i)
    return "https:#{value}" if value.start_with?("//")
    return "#{LEGACY_HOST}#{value}" if value.start_with?("/")

    if value.include?("/")
      "#{LEGACY_HOST}/#{value.sub(%r{\A/+}, '')}"
    else
      legacy_image_url
    end
  end

  def filename_reference?
    @raw_value.present? && !@raw_value.match?(%r{\Ahttps?://}i) && !@raw_value.start_with?("//", "/") && !@raw_value.include?("/")
  end

  def s3_bucket_url
    "#{LEGACY_S3_ROOT}/#{@raw_value}"
  end

  def legacy_image_url
    "#{LEGACY_HOST}/images/#{@raw_value}"
  end

  def wayback_variants(url)
    return [] if url.include?("web.archive.org/web/")

    WAYBACK_TIMESTAMPS.map { |timestamp| "https://web.archive.org/web/#{timestamp}/#{url}" }
  end
end
