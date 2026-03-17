class Edition < ApplicationRecord
  LEGACY_S3_ROOT = "https://s3-us-west-2.amazonaws.com/haggard".freeze

  belongs_to :novel
  has_many :illustrations, dependent: :destroy
  has_many :blog_posts, dependent: :destroy
  
  has_one_attached :cover_image, dependent: :purge_later
  
  validates :name, presence: true
  
  include PgSearch::Model
  pg_search_scope :search_by_name_and_publisher,
    against: [:name, :publisher, :publication_city],
    using: {
      tsearch: { prefix: true }
    }

  # Define searchable associations for Ransack (used by ActiveAdmin)
  def self.ransackable_associations(auth_object = nil)
    ["blog_posts", "illustrations", "novel"]
  end

  # Define searchable attributes for Ransack (used by ActiveAdmin)
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "name", "novel_id", "publication_city", "publication_year", "publisher", "updated_at"]
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
    return if publication_date.blank?

    match = publication_date.to_s.match(/\b(1[0-9]{3}|20[0-9]{2})\b/)
    match && match[1].to_i
  end

  def synthetic_placeholder?
    generated_placeholder? || test_placeholder?
  end

  def test_placeholder?
    name == "Illustrator Edition" &&
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

  private

  def generated_placeholder?
    name == "First Edition" &&
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
