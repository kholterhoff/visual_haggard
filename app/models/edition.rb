class Edition < ApplicationRecord
  include SafeUrlFields

  LEGACY_S3_ROOT = "https://s3-us-west-2.amazonaws.com/haggard".freeze
  TEST_PLACEHOLDER_NAME = "Illustrator Edition".freeze
  GENERATED_PLACEHOLDER_NAME = "First Edition".freeze
  STRING_MAXIMUM = 255

  belongs_to :novel
  has_many :illustrations, dependent: :destroy
  has_many :blog_posts, dependent: :destroy

  has_one_attached :cover_image, dependent: :purge_later

  validates :novel, presence: true
  validates :name, presence: true, length: { maximum: STRING_MAXIMUM }
  validates :publisher, :publication_date, :publication_city, :source, :long_name,
            length: { maximum: STRING_MAXIMUM }, allow_blank: true
  validates :cover_url, :cover_thumbnail_url,
            length: { maximum: STRING_MAXIMUM }, allow_blank: true
  validates_http_url_or_legacy_reference :cover_url, :cover_thumbnail_url

  include PgSearch::Model
  pg_search_scope :search_by_name_and_publisher,
    against: [:name, :publisher, :publication_city],
    using: {
      tsearch: { prefix: true }
    }

  scope :generated_placeholder_records, lambda {
    left_outer_joins(:illustrations, :blog_posts)
      .where(
        name: GENERATED_PLACEHOLDER_NAME,
        publication_date: "Unknown",
        publisher: "Unknown",
        publication_city: [nil, ""],
        source: [nil, ""],
        long_name: [nil, ""],
        cover_url: [nil, ""],
        cover_thumbnail_url: [nil, ""],
        image_file_name: [nil, ""]
      )
      .group("editions.id")
      .having("COUNT(DISTINCT illustrations.id) = 0")
      .having("COUNT(DISTINCT blog_posts.id) = 0")
  }

  scope :test_placeholder_records, lambda {
    left_outer_joins(:blog_posts, illustrations: :illustrator)
      .where(
        name: TEST_PLACEHOLDER_NAME,
        publication_date: [nil, ""],
        publisher: [nil, ""],
        publication_city: [nil, ""],
        source: [nil, ""],
        long_name: [nil, ""],
        cover_url: [nil, ""],
        cover_thumbnail_url: [nil, ""],
        image_file_name: [nil, ""]
      )
      .group("editions.id")
      .having("COUNT(DISTINCT blog_posts.id) = 0")
      .having("COUNT(DISTINCT illustrations.id) > 0")
      .having(Edition.test_placeholder_having_sql)
  }

  scope :publicly_visible, lambda {
    joins(:novel)
      .merge(Novel.publicly_visible)
      .where.not(id: generated_placeholder_records.select(:id))
      .where.not(id: test_placeholder_records.select(:id))
  }

  def self.ransackable_associations(_auth_object = nil)
    %w[blog_posts illustrations novel]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name novel_id publication_city publication_date publisher source updated_at]
  end

  def legacy_cover_reference
    cover_url.presence || image_file_name.presence || cover_thumbnail_url.presence
  end

  def resolved_cover_url(style: :original)
    return paperclip_cover_url(style:) if image_file_name.present?
    return DbImageUrlResolver.new(cover_url).preferred_public_url if cover_url.present?
    return DbImageUrlResolver.new(cover_thumbnail_url).preferred_public_url if cover_thumbnail_url.present?

    nil
  end

  def cover_source_candidates
    candidates = []
    candidates << paperclip_cover_url(style: :original) if image_file_name.present?
    candidates << paperclip_cover_url(style: :thumb) if image_file_name.present?
    candidates << DbImageUrlResolver.new(cover_url).preferred_public_url if cover_url.present?
    candidates << DbImageUrlResolver.new(cover_thumbnail_url).preferred_public_url if cover_thumbnail_url.present?
    candidates.compact.uniq
  end

  def display_cover_source(style: :original)
    cover_image.attached? ? cover_image : resolved_cover_url(style:)
  end

  def cover_source_priority
    return 0 if cover_image.attached?
    return 1 if image_file_name.present?
    return 2 if absolute_cover_reference?(cover_url)
    return 3 if absolute_cover_reference?(cover_thumbnail_url)
    return 4 if cover_url.present?
    return 5 if cover_thumbnail_url.present?

    6
  end

  def display_title
    name.presence || publication_date.presence || "Untitled Edition"
  end

  def publication_citation
    parts = []
    parts << publication_city if publication_city.present?
    parts << publisher if publisher.present? && publisher != "Unknown"
    details = parts.join(": ")

    if publication_date.present? && publication_date != "Unknown"
      details = details.present? ? "#{details}, #{publication_date}." : publication_date.to_s
    elsif details.present?
      details = "#{details}."
    end

    details.presence
  end

  def publication_year_value
    publication_date_parts[:year]
  end

  def publication_sort_key
    parts = publication_date_parts
    year = parts[:year]
    month = parts[:mon] || 0
    day = parts[:mday] || 0

    [year.nil? ? 1 : 0, year || Float::INFINITY, month, day, publication_date.to_s.downcase, id]
  end

  def synthetic_placeholder?
    generated_placeholder? || test_placeholder?
  end

  def test_placeholder?
    name == TEST_PLACEHOLDER_NAME &&
      publication_date.blank? &&
      publisher.blank? &&
      publication_city.blank? &&
      source.blank? &&
      long_name.blank? &&
      cover_url.blank? &&
      cover_thumbnail_url.blank? &&
      image_file_name.blank? &&
      illustrations.any? &&
      illustrations.all?(&:test_placeholder?) &&
      blog_posts.empty?
  end

  def self.test_placeholder_having_sql
    sanitize_sql_array(
      [
        <<~SQL.squish,
          COUNT(DISTINCT CASE
            WHEN illustrations.name = ?
             AND COALESCE(illustrations.description, '') = ''
             AND COALESCE(illustrations.page_number, '') = ''
             AND illustrations.image_url = ?
             AND illustrators.name = ?
            THEN illustrations.id
          END) = COUNT(DISTINCT illustrations.id)
        SQL
        Illustration::REPRESENTATIVE_PLACEHOLDER_NAME,
        Illustration::TEST_PLACEHOLDER_IMAGE_URL,
        Illustrator::PLACEHOLDER_NAME
      ]
    )
  end

  private

  def publication_date_parts
    @publication_date_parts ||= begin
      raw_value = publication_date.to_s.strip
      raw_value.present? ? Date._parse(raw_value, false).slice(:year, :mon, :mday) : {}
    rescue ArgumentError
      {}
    end
  end

  def generated_placeholder?
    name == GENERATED_PLACEHOLDER_NAME &&
      publication_date == "Unknown" &&
      publisher == "Unknown" &&
      publication_city.blank? &&
      source.blank? &&
      long_name.blank? &&
      cover_url.blank? &&
      cover_thumbnail_url.blank? &&
      image_file_name.blank? &&
      illustrations.empty? &&
      blog_posts.empty?
  end

  def paperclip_cover_url(style:)
    build_legacy_s3_url("editions", image_file_name, image_updated_at, style)
  end

  def build_legacy_s3_url(collection, filename, updated_at, style)
    return if filename.blank?

    url = "#{LEGACY_S3_ROOT}/#{collection}/images/#{legacy_id_partition}/#{style}/#{filename}"
    updated_at.present? ? "#{url}?#{updated_at.to_i}" : url
  end

  def legacy_id_partition
    "000/000/#{id}"
  end

  def absolute_cover_reference?(value)
    value.to_s.match?(%r{\Ahttps?://}i)
  end
end
