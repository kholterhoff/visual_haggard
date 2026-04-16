class Illustrator < ApplicationRecord
  include AssignsLowestAvailableId
  PERIODICAL_CAROUSEL_KEYWORDS = /\b(magazine|weekly|journal|newspaper)\b/i
  PREFERRED_CAROUSEL_EDITION_IDS = {
    4 => [109, 4, 79]
  }.freeze
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

  def self.preferred_carousel_edition_ids
    PREFERRED_CAROUSEL_EDITION_IDS
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
    if cover_source.present? && (matches_edition_cover?(illustration, style:) || illustration.cover_related?)
      return cover_source
    end

    representative_image_source_for(illustration, style:)
  end

  def cover_carousel_entries(style: :original, limit: 5)
    normalize_carousel_entries(
      prioritize_preferred_carousel_editions(editions_for_cover_carousel(style:)),
      limit:
    )
  end

  def showcase_carousel_entries(style: :original, limit: 5)
    cover_entries = cover_carousel_entries(style:, limit:)
    return cover_entries if cover_entries.any?

    edition_cover_entries = normalize_carousel_entries(
      prioritize_preferred_carousel_editions(editions_for_edition_cover_fallback(style:)),
      limit:
    )
    return edition_cover_entries if edition_cover_entries.any?

    normalize_carousel_entries(illustrations_for_carousel_fallback(style:), limit:)
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

  def preferred_carousel_edition_ids
    self.class.preferred_carousel_edition_ids.fetch(id, [])
  end

  def prioritize_preferred_carousel_editions(entries)
    preferred_ids = preferred_carousel_edition_ids
    return entries if preferred_ids.empty?

    entries
      .each_with_index
      .sort_by do |(entry, index)|
        preferred_index = preferred_ids.index(entry[:edition].id)
        [preferred_index.nil? ? 1 : 0, preferred_index || preferred_ids.length, index]
      end
      .map(&:first)
  end

  def representative_illustration_priority(illustration, style:)
    return 0 if matches_edition_cover?(illustration, style:)
    return 1 if illustration.cover_related?

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

  def editions_for_cover_carousel(style:)
    illustrations_grouped_by_edition
      .filter_map do |edition, illustrations|
        cover_illustration = cover_illustration_for_carousel(edition, illustrations, style:)
        next if cover_illustration.blank?

        cover_source = representative_cover_source_for(edition, style:) || representative_image_source_for(cover_illustration, style:)
        next if cover_source.blank?

        {
          edition:,
          illustration: cover_illustration,
          source: cover_source,
          entry_type: :cover,
          priority: cover_carousel_priority_for(edition, illustrations, cover_illustration, style:),
          supporting_illustration_count: supporting_illustration_count_for_carousel(illustrations, style:)
        }
      end
      .sort_by do |entry|
        [
          entry[:priority],
          -entry[:supporting_illustration_count],
          entry[:edition].publication_sort_key,
          entry[:edition].id,
          entry[:illustration].id
        ]
      end
  end

  def editions_for_edition_cover_fallback(style:)
    illustrations_grouped_by_edition
      .filter_map do |edition, illustrations|
        next if periodical_edition_for_carousel?(edition)

        representative_illustration = representative_illustration_for_carousel_fallback(illustrations, style:)
        next if representative_illustration.blank?

        cover_source = representative_cover_source_for(edition, style:)
        next if cover_source.blank?

        {
          edition:,
          illustration: representative_illustration,
          source: cover_source,
          entry_type: :edition_cover,
          priority: edition_title_priority_for_carousel(edition),
          supporting_illustration_count: supporting_illustration_count_for_carousel(illustrations, style:)
        }
      end
      .sort_by do |entry|
        [
          entry[:priority],
          -entry[:supporting_illustration_count],
          entry[:edition].publication_sort_key,
          entry[:edition].id,
          entry[:illustration].id
        ]
      end
  end

  def illustrations_for_carousel_fallback(style:)
    illustrations_grouped_by_edition
      .filter_map do |edition, illustrations|
        representative_illustration = representative_illustration_for_carousel_fallback(illustrations, style:)
        next if representative_illustration.blank?

        source = representative_image_source_for(representative_illustration, style:)
        next if source.blank?

        {
          edition:,
          illustration: representative_illustration,
          source: source,
          entry_type: :illustration,
          priority: illustration_fallback_priority(representative_illustration),
          supporting_illustration_count: supporting_illustration_count_for_carousel(illustrations, style:)
        }
      end
      .sort_by do |entry|
        [
          entry[:priority],
          -entry[:supporting_illustration_count],
          entry[:edition].publication_sort_key,
          entry[:edition].id,
          entry[:illustration].id
        ]
      end
  end

  def illustrations_grouped_by_edition
    representative_illustrations_for_selection(style: :original)
      .group_by(&:edition)
      .select { |edition, _illustrations| edition.present? && edition.novel.present? }
  end

  def cover_illustration_for_carousel(edition, illustrations, style:)
    explicit_cover_illustration = explicit_cover_illustration_for_carousel(illustrations, style:)
    return explicit_cover_illustration if explicit_cover_illustration.present?
    return unless edition_cover_fallback_for_carousel?(edition, illustrations, style:)

    illustrations
      .select { |illustration| representative_image_source_for(illustration, style:).present? }
      .min_by { |illustration| [edition_cover_fallback_priority(illustration), illustration.id] }
  end

  def explicit_cover_illustration_for_carousel(illustrations, style:)
    illustrations
      .select do |illustration|
        representative_image_source_for(illustration, style:).present? &&
          cover_evidence_for_carousel?(illustration, style:)
      end
      .min_by { |illustration| [cover_evidence_priority(illustration, style:), illustration.id] }
  end

  def cover_evidence_for_carousel?(illustration, style:)
    illustration.cover_related? || matches_edition_cover?(illustration, style:)
  end

  def cover_evidence_priority(illustration, style:)
    return 0 if matches_edition_cover?(illustration, style:)
    return 1 if illustration.page_number.to_s.match?(/dust jacket/i)
    return 2 if illustration.page_number.to_s.match?(/cover|wrapper/i)

    3
  end

  def edition_cover_fallback_for_carousel?(edition, illustrations, style:)
    representative_cover_source_for(edition, style:).present? &&
      !periodical_edition_for_carousel?(edition) &&
      strong_edition_presence_for_carousel?(illustrations, style:)
  end

  def edition_cover_fallback_priority(illustration)
    return 0 if illustration.page_number.to_s.match?(/frontispiece/i)

    1
  end

  def periodical_edition_for_carousel?(edition)
    [edition.display_title, edition.publisher, edition.long_name]
      .compact
      .join(" ")
      .match?(PERIODICAL_CAROUSEL_KEYWORDS)
  end

  def edition_title_priority_for_carousel(edition)
    title = [edition.display_title, edition.long_name]
      .compact
      .join(" ")

    return 0 if title.match?(/\bauthorized edition\b/i)
    return 1 if title.match?(/\b1st\b|\bfirst\b/i)
    return 2 if title.match?(/\bnew edition\b|\bsilver edition\b/i)

    3
  end

  def strong_edition_presence_for_carousel?(illustrations, style:)
    visible_illustrations = supporting_illustrations_for_carousel(illustrations, style:)
    visible_illustrations.any? { |illustration| illustration.page_number.to_s.match?(/frontispiece/i) } ||
      visible_illustrations.many?
  end

  def supporting_illustrations_for_carousel(illustrations, style:)
    illustrations.select { |illustration| representative_image_source_for(illustration, style:).present? }
  end

  def supporting_illustration_count_for_carousel(illustrations, style:)
    supporting_illustrations_for_carousel(illustrations, style:).size
  end

  def representative_illustration_for_carousel_fallback(illustrations, style:)
    supporting_illustrations_for_carousel(illustrations, style:)
      .min_by { |illustration| [illustration_fallback_priority(illustration), illustration.id] }
  end

  def illustration_fallback_priority(illustration)
    page_marker = illustration.page_number.to_s
    return 0 if page_marker.match?(/frontispiece/i)
    return 1 if illustration.cover_related?

    2
  end

  def cover_carousel_priority_for(edition, illustrations, cover_illustration, style:)
    return 0 if matches_edition_cover?(cover_illustration, style:) || cover_illustration.cover_related?
    return 1 + edition_title_priority_for_carousel(edition) if edition_cover_fallback_for_carousel?(edition, illustrations, style:)

    5
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

  def normalize_carousel_entries(entries, limit:)
    entries
      .first(limit)
      .map do |entry|
        edition = entry[:edition]
        {
          illustration: entry[:illustration],
          edition:,
          novel: edition.novel,
          source: entry[:source],
          entry_type: entry[:entry_type] || :cover
        }
      end
  end
end
