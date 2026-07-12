# Builds the ordered edition pool behind the homepage hero cover wall and the
# featured-edition carousel. Shared by HomeController and the
# hero_covers:generate rake task so both always agree on which editions the
# hero shows.
class HomeHeroPool
  HERO_REEL_COUNT = 5
  HERO_REEL_LENGTH = 8
  FEATURED_EDITION_COUNT = 6
  FEATURED_NOVEL_IDS = [48, 17].freeze
  FEATURED_EDITION_IDS = [504, 501].freeze

  def featured_editions
    @featured_editions ||= begin
      featured = featured_novel_cover_editions + featured_explicit_editions
      featured = featured.select do |edition|
        edition.display_cover_source(style: :original).present? && !edition.synthetic_placeholder?
      end

      featured = featured.uniq(&:id)
      featured.concat(cover_editions.reject { |edition| featured.any? { |featured_edition| featured_edition.id == edition.id } })
      featured.first(FEATURED_EDITION_COUNT)
    end
  end

  def reels
    @reels ||= Array.new(HERO_REEL_COUNT) do |reel_index|
      reel_editions.each_with_index.filter_map do |edition, index|
        edition if index % HERO_REEL_COUNT == reel_index
      end
    end
  end

  # The ordered editions filling the hero reels (may repeat when the archive
  # has fewer cover-ready editions than reel slots).
  def reel_editions
    @reel_editions ||= begin
      hero_pool = (featured_editions + cover_editions).uniq(&:id)
      required_count = HERO_REEL_COUNT * HERO_REEL_LENGTH
      reel_pool = hero_pool.first(required_count)
      reel_pool = hero_pool.cycle.take(required_count) if reel_pool.size < required_count
      reel_pool
    end
  end

  def cover_editions
    @cover_editions ||= Edition.publicly_visible
                               .includes(:novel, { cover_image_attachment: :blob }, { illustrations: { image_attachment: :blob } })
                               .order(:id)
                               .select { |edition| edition.display_cover_source(style: :original).present? }
  end

  private

  def featured_novel_cover_editions
    featured_novels = Novel.includes(editions: [{ cover_image_attachment: :blob }, { illustrations: { image_attachment: :blob } }])
                           .where(id: FEATURED_NOVEL_IDS)
                           .index_by(&:id)

    FEATURED_NOVEL_IDS.filter_map do |novel_id|
      featured_novels[novel_id]&.lead_cover_edition(style: :original)
    end
  end

  def featured_explicit_editions
    editions = cover_editions.select { |edition| FEATURED_EDITION_IDS.include?(edition.id) }.index_by(&:id)

    FEATURED_EDITION_IDS.filter_map do |edition_id|
      editions[edition_id]
    end
  end
end
