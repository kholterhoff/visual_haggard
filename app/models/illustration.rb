class Illustration < ApplicationRecord
  include SafeUrlFields

  LEGACY_S3_ROOT = "https://s3-us-west-2.amazonaws.com/haggard".freeze
  REPRESENTATIVE_PLACEHOLDER_NAME = "Representative illustration".freeze
  TEST_PLACEHOLDER_IMAGE_URL = "https://example.com/representative.jpg".freeze
  STRING_MAXIMUM = 255
  DESCRIPTION_MAXIMUM = 100_000

  belongs_to :edition
  belongs_to :illustrator, optional: true
  has_many :blog_posts, dependent: :destroy

  has_one_attached :image, dependent: :purge_later

  acts_as_taggable_on :tags

  validates :edition, presence: true
  validates :name, presence: true, length: { maximum: STRING_MAXIMUM }
  validates :artist, :page_number,
            length: { maximum: STRING_MAXIMUM }, allow_blank: true
  validates :image_url, :image_thumbnail_url, :google_book_link, :gutenberg_link, :internet_archive_link,
            length: { maximum: STRING_MAXIMUM }, allow_blank: true
  validates :description, length: { maximum: DESCRIPTION_MAXIMUM }, allow_blank: true
  validates_http_url_or_legacy_reference :image_url, :image_thumbnail_url
  validates_http_url :google_book_link, :gutenberg_link, :internet_archive_link

  delegate :novel, to: :edition

  scope :browseable, lambda {
    joins(edition: :novel)
      .merge(Novel.publicly_visible)
      .where.not(edition_id: Edition.generated_placeholder_records.select(:id))
      .where.not(edition_id: Edition.test_placeholder_records.select(:id))
      .distinct
  }
  scope :with_display_source, lambda {
    left_outer_joins(:image_attachment)
      .where(
        "COALESCE(illustrations.image_file_name, '') <> '' OR COALESCE(illustrations.image_url, '') <> '' OR COALESCE(illustrations.image_thumbnail_url, '') <> '' OR active_storage_attachments.id IS NOT NULL"
      )
      .distinct
  }

  def self.ransackable_associations(_auth_object = nil)
    %w[base_tags blog_posts edition illustrator tag_taggings taggings tags]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[artist created_at description edition_id id illustrator_id name page_number updated_at]
  end

  include PgSearch::Model
  pg_search_scope :search_by_name_and_description,
    against: [:name, :description, :artist],
    using: {
      tsearch: { prefix: true }
    }

  pg_search_scope :search_all,
    against: [:name, :description, :artist, :page_number],
    associated_against: {
      edition: [:name, :publisher],
      illustrator: [:name]
    },
    using: {
      tsearch: { prefix: true }
    }

  def legacy_image_reference
    image_url.presence || image_file_name.presence || image_thumbnail_url.presence
  end

  def resolved_image_url(style: :original)
    return paperclip_image_url(style:) if image_file_name.present?
    return DbImageUrlResolver.new(image_url).preferred_public_url if image_url.present?
    return DbImageUrlResolver.new(image_thumbnail_url).preferred_public_url if image_thumbnail_url.present?

    nil
  end

  def image_source_candidates
    candidates = []
    candidates << paperclip_image_url(style: :original) if image_file_name.present?
    candidates << paperclip_image_url(style: :thumb) if image_file_name.present?
    candidates << DbImageUrlResolver.new(image_url).preferred_public_url if image_url.present?
    candidates << DbImageUrlResolver.new(image_thumbnail_url).preferred_public_url if image_thumbnail_url.present?
    candidates.compact.uniq
  end

  def display_image_source(style: :original)
    image.attached? ? image : resolved_image_url(style:)
  end

  def test_placeholder?
    name == REPRESENTATIVE_PLACEHOLDER_NAME &&
      description.blank? &&
      page_number.blank? &&
      image_url == TEST_PLACEHOLDER_IMAGE_URL &&
      illustrator&.name == Illustrator::PLACEHOLDER_NAME
  end

  private

  # Archive metadata uses freeform labels such as "Frontispiece" and "Dust Jacket",
  # so page_number intentionally remains a flexible string field.
  def paperclip_image_url(style:)
    build_legacy_s3_url("illustrations", image_file_name, image_updated_at, style)
  end

  def build_legacy_s3_url(collection, filename, updated_at, style)
    return if filename.blank?

    url = "#{LEGACY_S3_ROOT}/#{collection}/images/#{legacy_id_partition}/#{style}/#{filename}"
    updated_at.present? ? "#{url}?#{updated_at.to_i}" : url
  end

  def legacy_id_partition
    "000/000/#{id}"
  end
end
