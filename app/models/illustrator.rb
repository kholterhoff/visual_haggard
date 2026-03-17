class Illustrator < ApplicationRecord
  COVER_KEYWORDS = /\b(cover|dust jacket|jacket|wrapper|wrappers)\b/i
  PLACEHOLDER_NAME = "Efficient Illustrator".freeze
  STRING_MAXIMUM = 255
  BIO_MAXIMUM = 100_000

  has_many :illustrations, dependent: :destroy

  validates :name, presence: true, length: { maximum: STRING_MAXIMUM }
  validates :bio, length: { maximum: BIO_MAXIMUM }, allow_blank: true

  include PgSearch::Model
  scope :synthetic_placeholder_records, lambda {
    left_outer_joins(:illustrations)
      .where(name: PLACEHOLDER_NAME, bio: [nil, ""])
      .group("illustrators.id")
      .having("COUNT(DISTINCT illustrations.id) > 0")
      .having(Illustrator.synthetic_placeholder_having_sql)
  }
  scope :publicly_visible, -> { where.not(id: synthetic_placeholder_records.select(:id)) }

  pg_search_scope :search_by_name_and_bio,
    against: [:name, :bio],
    using: {
      tsearch: { prefix: true }
    }

  def self.ransackable_associations(_auth_object = nil)
    %w[illustrations]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[bio created_at id name updated_at]
  end

  def representative_illustration(style: :original)
    representative_illustrations_for_selection(style:)
      .to_a
      .select { |illustration| representative_image_source_for(illustration, style:).present? }
      .min_by { |illustration| [representative_illustration_priority(illustration, style:), illustration.id] }
  end

  def representative_image_source(style: :original)
    illustration = representative_illustration(style:)
    return unless illustration

    representative_image_source_for(illustration, style:)
  end

  def representative_grid_image_source(style: :original)
    illustration = representative_illustration(style:)
    return unless illustration

    cover_source = representative_cover_source_for(illustration.edition, style:)
    if cover_source.present? && (matches_edition_cover?(illustration, style:) || cover_like_illustration?(illustration))
      return cover_source
    end

    representative_image_source_for(illustration, style:)
  end

  def directory_last_name
    token = name.to_s.strip.split(/\s+/).last.to_s.gsub(/\A[^A-Za-z]+|[^A-Za-z]+\z/, "")
    token.presence || name.to_s
  end

  def directory_letter
    letter = directory_last_name[0].to_s.upcase
    letter.match?(/[A-Z]/) ? letter : "#"
  end

  def directory_sort_key
    [directory_last_name.downcase, name.to_s.downcase]
  end

  def synthetic_placeholder?
    name == PLACEHOLDER_NAME &&
      bio.blank? &&
      illustrations.any? &&
      illustrations.all?(&:test_placeholder?)
  end

  def self.synthetic_placeholder_having_sql
    sanitize_sql_array(
      [
        <<~SQL.squish,
          COUNT(DISTINCT CASE
            WHEN illustrations.name = ?
             AND COALESCE(illustrations.description, '') = ''
             AND COALESCE(illustrations.page_number, '') = ''
             AND illustrations.image_url = ?
            THEN illustrations.id
          END) = COUNT(DISTINCT illustrations.id)
        SQL
        Illustration::REPRESENTATIVE_PLACEHOLDER_NAME,
        Illustration::TEST_PLACEHOLDER_IMAGE_URL
      ]
    )
  end

  private

  def representative_illustration_priority(illustration, style:)
    return 0 if matches_edition_cover?(illustration, style:)
    return 1 if cover_like_illustration?(illustration)

    2
  end

  def matches_edition_cover?(illustration, style:)
    edition = illustration.edition
    return false unless edition

    illustration_source = representative_image_source_for(illustration, style:)
    edition_source = representative_cover_source_for(edition, style:)
    return false unless illustration_source.is_a?(String) && edition_source.is_a?(String)

    illustration_source == edition_source
  end

  def cover_like_illustration?(illustration)
    [illustration.name, illustration.page_number, illustration.description]
      .compact
      .join(" ")
      .match?(COVER_KEYWORDS)
  end

  def representative_illustrations_for_selection(style:)
    if representative_illustrations_preloaded?
      illustrations.select { |illustration| illustration.edition&.novel.present? }
    else
      illustrations
        .browseable
        .with_display_source
        .includes(image_attachment: :blob, edition: [:novel, { cover_image_attachment: :blob }])
        .order(:id)
    end
  end

  def representative_illustrations_preloaded?
    association(:illustrations).loaded? &&
      illustrations.all? do |illustration|
        illustration.association(:image_attachment).loaded? &&
          illustration.association(:edition).loaded? &&
          illustration.edition.present? &&
          illustration.edition.association(:novel).loaded? &&
          illustration.edition.association(:cover_image_attachment).loaded?
      end
  end

  def representative_image_source_for(illustration, style:)
    if illustration.association(:image_attachment).loaded?
      return illustration.image if illustration.image_attachment.present?
    end

    legacy_source = illustration.resolved_image_url(style:)
    return legacy_source if legacy_source.present?

    illustration.image if illustration.image.attached?
  end

  def representative_cover_source_for(edition, style:)
    if edition.association(:cover_image_attachment).loaded?
      return edition.cover_image if edition.cover_image_attachment.present?
    end

    edition.resolved_cover_url(style:)
  end
end
