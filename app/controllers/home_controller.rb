class HomeController < ApplicationController
  HERO_REEL_COUNT = 5
  HERO_REEL_LENGTH = 8
  FEATURED_EDITION_COUNT = 6
  FEATURED_NOVEL_IDS = [48, 17].freeze
  FEATURED_EDITION_IDS = [504, 501].freeze
  STYLE_ILLUSTRATOR_IDS = [4, 35].freeze
  STYLE_EDITION_IDS = [50, 109].freeze
  STYLE_NOVEL_TITLE = "King Solomon's Mines".freeze
  PERIODICAL_ILLUSTRATION_IDS = [1145, 2045, 2042, 1962].freeze
  PERIODICAL_EDITION_IDS = [510].freeze
  PAPERBACK_ILLUSTRATOR_IDS = [69, 70, 61, 68].freeze
  BIOGRAPHY_PORTRAIT_EDITION_ID = 111
  BIOGRAPHY_PORTRAIT_NAME = "H. Rider Haggard"
  BIOGRAPHY_NOVEL_TITLES = {
    dawn: "Dawn",
    king_solomons_mines: "King Solomon's Mines",
    she: "She, A History of Adventure",
    allan_quatermain: "Allan Quatermain",
    maiwas_revenge: "Maiwa's Revenge; Or, The War of the Little Hand"
  }.freeze
  EDITORS_STATEMENT_NOVEL_TITLES = {
    king_solomons_mines: "King Solomon's Mines",
    dawn: "Dawn",
    she: "She, A History of Adventure"
  }.freeze
  EDITORS_STATEMENT_ILLUSTRATOR_NAMES = {
    maurice_greiffenhagen: "Maurice Greiffenhagen",
    e_k_johnson: "E. K. Johnson",
    wal_paget: "Walter Paget",
    w_russell_flint: "Russell Flint",
    a_c_michael: "A. C. Michael",
    charles_kerr: "Charles Kerr"
  }.freeze

  def index
    cover_editions = cover_ready_editions
    @featured_editions = build_featured_editions(cover_editions)
    @hero_cover_reels = build_hero_cover_reels(@featured_editions, cover_editions)
    @illustration_count = Illustration.count
    @style_illustrators = build_style_illustrators
    @style_editions = build_style_editions(cover_editions)
    @style_novel = Novel.publicly_visible.find_by(name: STYLE_NOVEL_TITLE)
    @timeline_groups = build_edition_timeline
    @periodical_examples = build_periodical_examples
    @paperback_illustrators = build_paperback_illustrators
  end

  def biography
    edition = Edition.includes(:novel, illustrations: :image_attachment).find_by(id: BIOGRAPHY_PORTRAIT_EDITION_ID)
    @biography_portrait = edition&.illustrations&.find do |illustration|
      illustration.name == BIOGRAPHY_PORTRAIT_NAME
    end
    @biography_novels = build_biography_novels
  end

  def editors_statement
    @editors_statement_novels = build_editors_statement_novels
    @editors_statement_illustrators = build_editors_statement_illustrators
  end

  private

  def build_featured_editions(cover_editions)
    featured = featured_novel_cover_editions + featured_explicit_editions
    featured = featured.select do |edition|
      edition.display_cover_source(style: :original).present? && !edition.synthetic_placeholder?
    end

    featured = featured.uniq(&:id)
    featured.concat(cover_editions.reject { |edition| featured.any? { |featured_edition| featured_edition.id == edition.id } })
    featured.first(FEATURED_EDITION_COUNT)
  end

  def build_hero_cover_reels(featured_editions, cover_editions)
    hero_pool = (featured_editions + cover_editions).uniq(&:id)
    required_count = HERO_REEL_COUNT * HERO_REEL_LENGTH
    reel_pool = hero_pool.first(required_count)
    reel_pool = hero_pool.cycle.take(required_count) if reel_pool.size < required_count

    Array.new(HERO_REEL_COUNT) do |reel_index|
      reel_pool.each_with_index.filter_map do |edition, index|
        edition if index % HERO_REEL_COUNT == reel_index
      end
    end
  end

  def featured_novel_cover_editions
    featured_novels = Novel.includes(editions: [{ cover_image_attachment: :blob }, { illustrations: { image_attachment: :blob } }])
                           .where(id: FEATURED_NOVEL_IDS)
                           .index_by(&:id)

    FEATURED_NOVEL_IDS.filter_map do |novel_id|
      featured_novels[novel_id]&.lead_cover_edition(style: :original)
    end
  end

  def featured_explicit_editions
    editions = cover_ready_editions.select { |edition| FEATURED_EDITION_IDS.include?(edition.id) }.index_by(&:id)

    FEATURED_EDITION_IDS.filter_map do |edition_id|
      editions[edition_id]
    end
  end

  def cover_ready_editions
    @cover_ready_editions ||= Edition.publicly_visible
                                     .includes(:novel, { cover_image_attachment: :blob }, { illustrations: { image_attachment: :blob } })
                                     .order(:id)
                                     .select { |edition| edition.display_cover_source(style: :original).present? }
  end

  def build_style_illustrators
    illustrators = Illustrator.publicly_visible
                              .includes(illustrations: [{ image_attachment: :blob }, { edition: [:novel, { cover_image_attachment: :blob }] }])
                              .where(id: STYLE_ILLUSTRATOR_IDS)
                              .index_by(&:id)

    STYLE_ILLUSTRATOR_IDS.filter_map do |illustrator_id|
      illustrators[illustrator_id]
    end
  end

  def build_style_editions(cover_editions)
    spotlight_editions = cover_editions.select { |edition| STYLE_EDITION_IDS.include?(edition.id) }.index_by(&:id)

    STYLE_EDITION_IDS.to_h do |edition_id|
      [edition_id, spotlight_editions[edition_id]]
    end
  end

  def build_edition_timeline
    Edition.publicly_visible
           .includes(:novel)
           .order(:id)
           .select { |edition| edition.publication_year_value.present? }
           .group_by(&:publication_year_value)
           .sort_by { |year, _| year }
           .map do |year, grouped_editions|
             {
               year:,
               editions: grouped_editions.sort_by { |edition| [edition.novel.name.downcase, edition.display_title.downcase, edition.id] }
             }
           end
  end

  def build_periodical_examples
    illustrations = Illustration.includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
                                .where(id: PERIODICAL_ILLUSTRATION_IDS)
                                .index_by(&:id)
    editions = Edition.includes(:novel, { cover_image_attachment: :blob })
                      .where(id: PERIODICAL_EDITION_IDS)
                      .index_by(&:id)

    example_records = PERIODICAL_ILLUSTRATION_IDS.filter_map do |illustration_id|
      illustration = illustrations[illustration_id]
      next unless illustration

      {
        kind: :illustration,
        label: "Periodical illustration",
        title: illustration.edition.display_title,
        subtitle: illustration.novel.name,
        detail: illustration.edition.publication_date,
        source: illustration.edition.source,
        image_source: illustration.display_image_source(style: :original),
        path: illustration_path(illustration)
      }
    end

    example_records.concat(
      PERIODICAL_EDITION_IDS.filter_map do |edition_id|
        edition = editions[edition_id]
        next unless edition

        {
          kind: :edition,
          label: "Magazine edition",
          title: edition.display_title,
          subtitle: edition.novel.name,
          detail: edition.publication_date,
          source: edition.source,
          image_source: edition.display_cover_source(style: :original),
          path: edition_path(edition)
        }
      end
    )

    example_records
  end

  def build_paperback_illustrators
    illustrators = Illustrator.publicly_visible
                              .includes(illustrations: [{ image_attachment: :blob }, { edition: [:novel, { cover_image_attachment: :blob }] }])
                              .where(id: PAPERBACK_ILLUSTRATOR_IDS)
                              .index_by(&:id)

    PAPERBACK_ILLUSTRATOR_IDS.filter_map do |illustrator_id|
      illustrators[illustrator_id]
    end
  end

  def build_biography_novels
    biography_novels = Novel.publicly_visible.where(name: BIOGRAPHY_NOVEL_TITLES.values).index_by(&:name)

    BIOGRAPHY_NOVEL_TITLES.transform_values do |title|
      biography_novels[title]
    end
  end

  def build_editors_statement_novels
    novels = Novel.publicly_visible.where(name: EDITORS_STATEMENT_NOVEL_TITLES.values).index_by(&:name)

    EDITORS_STATEMENT_NOVEL_TITLES.transform_values do |title|
      novels[title]
    end
  end

  def build_editors_statement_illustrators
    illustrators = Illustrator.publicly_visible.where(name: EDITORS_STATEMENT_ILLUSTRATOR_NAMES.values).index_by(&:name)

    EDITORS_STATEMENT_ILLUSTRATOR_NAMES.transform_values do |name|
      illustrators[name]
    end
  end
end
