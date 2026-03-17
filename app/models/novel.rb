class Novel < ApplicationRecord
  DIRECTORY_ARTICLE_PREFIX = /\A(?:a|an|the)\s+/i
  ARCHIVE_PAGE_SIZE = 12
  PLACEHOLDER_NAME = "Illustrator Novel".freeze

  has_many :editions, dependent: :destroy
  has_many :illustrations, through: :editions
  has_many :blog_posts, dependent: :destroy
  
  acts_as_taggable_on :tags

  scope :publicly_visible, -> { where.not(name: PLACEHOLDER_NAME) }
  
  validates :name, presence: true
  
  include PgSearch::Model
  pg_search_scope :search_by_name_and_description,
    against: [:name, :description],
    using: {
      tsearch: { prefix: true }
    }

  # Define searchable associations for Ransack (used by ActiveAdmin)
  def self.ransackable_associations(auth_object = nil)
    ["base_tags", "blog_posts", "editions", "illustrations", "tag_taggings", "taggings", "tags"]
  end

  # Define searchable attributes for Ransack (used by ActiveAdmin)
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "description", "id", "name", "updated_at"]
  end

  def visible_editions
    editions.reject(&:synthetic_placeholder?)
  end

  def synthetic_placeholder?
    name == PLACEHOLDER_NAME &&
      description.blank? &&
      editions.any? &&
      editions.all?(&:test_placeholder?)
  end

  def lead_cover_edition(style: :original)
    visible_editions
      .select { |edition| edition.display_cover_source(style:).present? }
      .min_by { |edition| [edition.cover_source_priority, edition.id] }
  end

  def lead_illustration(style: :original)
    visible_editions.flat_map(&:illustrations).find do |illustration|
      illustration.display_image_source(style:).present?
    end
  end

  def display_cover_source(style: :original)
    cover_edition = lead_cover_edition(style:)
    return cover_edition.display_cover_source(style:) if cover_edition

    lead_illustration(style:)&.display_image_source(style:)
  end

  def directory_title
    normalized_title = name.to_s.strip.sub(DIRECTORY_ARTICLE_PREFIX, "")
    normalized_title.presence || name.to_s
  end

  def directory_letter
    letter = directory_title[0].to_s.upcase
    letter.match?(/[A-Z]/) ? letter : "#"
  end

  def directory_sort_key
    [directory_title.downcase, name.to_s.downcase]
  end
end
