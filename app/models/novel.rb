class Novel < ApplicationRecord
  DIRECTORY_ARTICLE_PREFIX = /\A(?:a|an|the)\s+/i
  ARCHIVE_PAGE_SIZE = 12
  PLACEHOLDER_NAME = "Illustrator Novel".freeze
  STRING_MAXIMUM = 255
  DESCRIPTION_MAXIMUM = 100_000
  SHORT_TITLE_OVERRIDES = {
    "Allan and the Holy Flower [The Holy Flower]" => "Allan and the Holy Flower",
    "Benita [The Spirit of Bambatse]" => "Benita",
    "Fair Margaret [Margaret]" => "Fair Margaret",
    "Lysbeth, A Tale of the Dutch" => "Lysbeth",
    "Pearl-Maiden: A Tale of the Fall of Jerusalem" => "Pearl-Maiden",
    "Maiwa's Revenge; Or, The War of the Little Hand" => "Maiwa's Revenge",
    "The Mahatma and the Hare, A Dream Story" => "The Mahatma and the Hare",
    "She, A History of Adventure" => "She"
  }.freeze

  has_many :editions, dependent: :destroy
  has_many :illustrations, through: :editions
  has_many :blog_posts, dependent: :destroy

  acts_as_taggable_on :tags

  scope :publicly_visible, -> { where.not(name: PLACEHOLDER_NAME) }

  validates :name, presence: true, length: { maximum: STRING_MAXIMUM }
  validates :description, length: { maximum: DESCRIPTION_MAXIMUM }, allow_blank: true

  include PgSearch::Model
  pg_search_scope :search_by_name_and_description,
    against: [:name, :description],
    using: {
      tsearch: { prefix: true }
    }

  def self.ransackable_associations(_auth_object = nil)
    %w[base_tags blog_posts editions illustrations tag_taggings taggings tags]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at description id name updated_at]
  end

  def visible_editions
    if association(:editions).loaded?
      editions.reject(&:synthetic_placeholder?)
    else
      editions.merge(Edition.publicly_visible)
    end
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
    if lead_illustrations_preloaded?
      visible_editions.flat_map(&:illustrations).find { |illustration| illustration.display_image_source(style:).present? }
    else
      illustrations
        .joins(edition: :novel)
        .merge(Novel.publicly_visible)
        .where.not(edition_id: Edition.generated_placeholder_records.select(:id))
        .where.not(edition_id: Edition.test_placeholder_records.select(:id))
        .with_display_source
        .includes(image_attachment: :blob)
        .order(:edition_id, :id)
        .first
    end
  end

  def display_cover_source(style: :original)
    cover_edition = lead_cover_edition(style:)
    return cover_edition.display_cover_source(style:) if cover_edition

    lead_illustration(style:)&.display_image_source(style:)
  end

  def long_title
    name.to_s
  end

  def short_title
    SHORT_TITLE_OVERRIDES.fetch(long_title, long_title)
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

  private

  def lead_illustrations_preloaded?
    association(:editions).loaded? &&
      visible_editions.all? { |edition| edition.association(:illustrations).loaded? }
  end
end
