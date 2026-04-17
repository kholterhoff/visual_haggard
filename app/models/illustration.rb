class Illustration < ApplicationRecord
  include AssignsLowestAvailableId
  include SafeUrlFields

  COVER_KEYWORDS = /\b(cover|dust jacket|jacket|wrapper|wrappers)\b/i
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

  before_validation :normalize_identical_image_group
  before_validation :normalize_text_moment_group

  validates :edition, presence: true
  validates :name, presence: true, length: { maximum: STRING_MAXIMUM }
  validates :artist, :page_number,
            length: { maximum: STRING_MAXIMUM }, allow_blank: true
  validates :identical_image_group, :text_moment_group, length: { maximum: STRING_MAXIMUM }, allow_blank: true
  validates :image_url, :image_thumbnail_url, :google_book_link, :gutenberg_link, :internet_archive_link,
            length: { maximum: STRING_MAXIMUM }, allow_blank: true
  validates :description, :editor_notes, length: { maximum: DESCRIPTION_MAXIMUM }, allow_blank: true
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

  def self.identical_image_group_supported?
    group_column_supported?(:identical_image_group)
  end

  def self.text_moment_group_supported?
    group_column_supported?(:text_moment_group)
  end

  def self.group_column_supported?(column_name)
    column_name = column_name.to_s
    return true if columns_hash.key?(column_name)

    if connection.data_source_exists?(table_name) && connection.column_exists?(table_name, column_name)
      reset_column_information
      return columns_hash.key?(column_name)
    end

    false
  rescue ActiveRecord::ActiveRecordError
    false
  end

  def self.build_identical_image_group_token
    build_group_token("illustration-group")
  end

  def self.build_text_moment_group_token
    build_group_token("text-moment-group")
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[base_tags blog_posts edition illustrator tag_taggings taggings tags]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[artist created_at description edition_id editor_notes id illustrator_id name page_number updated_at]
  end

  include PgSearch::Model
  pg_search_scope :search_by_name_and_description,
    against: [:name, :description, :editor_notes, :artist],
    using: {
      tsearch: { prefix: true }
    }

  pg_search_scope :search_all,
    against: [:name, :description, :editor_notes, :artist, :page_number],
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

  def cover_related?
    [name, page_number, description].compact.join(" ").match?(COVER_KEYWORDS)
  end

  def identical_image_group
    return unless self.class.identical_image_group_supported?

    self[:identical_image_group]
  end

  def identical_image_group=(value)
    return unless self.class.identical_image_group_supported?

    self[:identical_image_group] = value
  end

  def text_moment_group
    return unless self.class.text_moment_group_supported?

    self[:text_moment_group]
  end

  def text_moment_group=(value)
    return unless self.class.text_moment_group_supported?

    self[:text_moment_group] = value
  end

  def other_identical_illustrations(scope = Illustration.all)
    return scope.none unless self.class.identical_image_group_supported?
    return scope.none if identical_image_group.blank?

    scope.where(identical_image_group: identical_image_group).where.not(id: id)
  end

  def identical_image_grouped_with?(other_illustration)
    return false unless self.class.identical_image_group_supported?
    return false if other_illustration.blank? || identical_image_group.blank?

    identical_image_group == other_illustration.identical_image_group
  end

  def other_text_moment_illustrations(scope = Illustration.all)
    return scope.none unless self.class.text_moment_group_supported?
    return scope.none if text_moment_group.blank?

    scope.where(text_moment_group: text_moment_group).where.not(id: id)
  end

  def text_moment_grouped_with?(other_illustration)
    return false unless self.class.text_moment_group_supported?
    return false if other_illustration.blank? || text_moment_group.blank?

    text_moment_group == other_illustration.text_moment_group
  end

  def other_illustrations_from_novel
    Illustration.where(edition_id: novel.editions.select(:id)).where.not(id: id)
  end

  def assign_identical_siblings_from_novel!(selected_sibling_ids)
    return unless self.class.identical_image_group_supported?

    assign_grouped_siblings_from_novel!(selected_sibling_ids, group_column: :identical_image_group) do
      self.class.build_identical_image_group_token
    end
  end

  def assign_text_moment_siblings_from_novel!(selected_sibling_ids)
    return unless self.class.text_moment_group_supported?

    assign_grouped_siblings_from_novel!(selected_sibling_ids, group_column: :text_moment_group) do
      self.class.build_text_moment_group_token
    end
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
  def normalize_identical_image_group
    normalize_group_token(:identical_image_group)
  end

  def normalize_text_moment_group
    normalize_group_token(:text_moment_group)
  end

  def assign_grouped_siblings_from_novel!(selected_sibling_ids, group_column:)
    sibling_ids = Array(selected_sibling_ids).map(&:to_i).uniq
    managed_siblings = other_illustrations_from_novel
    managed_sibling_ids = managed_siblings.pluck(:id)
    selected_siblings = managed_siblings.where(id: sibling_ids).to_a
    selected_ids = selected_siblings.map(&:id)
    unselected_ids = managed_sibling_ids - selected_ids
    current_group = public_send(group_column).presence
    selected_groups = selected_siblings.map { |illustration| illustration.public_send(group_column).presence }.compact
    groups_to_merge = ([current_group] + selected_groups).compact.uniq
    timestamp = Time.current

    transaction do
      if selected_siblings.any?
        target_group = current_group || selected_groups.first || yield

        if groups_to_merge.any?
          Illustration.where(group_column => groups_to_merge).update_all(group_column => target_group, updated_at: timestamp)
        end

        Illustration.where(id: [id] + selected_ids).update_all(group_column => target_group, updated_at: timestamp)

        if unselected_ids.any?
          Illustration.where(id: unselected_ids, group_column => target_group).update_all(group_column => nil, updated_at: timestamp)
        end
      elsif current_group.present?
        external_group_records_exist = Illustration.where(group_column => current_group)
                                                  .where.not(id: [id] + managed_sibling_ids)
                                                  .exists?

        if external_group_records_exist
          Illustration.where(id: unselected_ids, group_column => current_group).update_all(group_column => nil, updated_at: timestamp)
        else
          Illustration.where(id: [id] + managed_sibling_ids, group_column => current_group).update_all(group_column => nil, updated_at: timestamp)
        end
      end
    end

    reload
  end

  def normalize_group_token(group_column)
    supported =
      case group_column
      when :identical_image_group
        self.class.identical_image_group_supported?
      when :text_moment_group
        self.class.text_moment_group_supported?
      else
        false
      end
    return unless supported

    public_send("#{group_column}=", public_send(group_column).to_s.strip.presence)
  end

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

  def self.build_group_token(prefix)
    "#{prefix}-#{SecureRandom.hex(10)}"
  end
end
