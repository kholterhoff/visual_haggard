class ArchiveSearch
  ILLUSTRATIONS_PER_PAGE = 36
  SECTION_LIMIT = 12

  attr_reader :query, :page

  def initialize(query:, page:)
    @query = query.to_s.squish
    @page = page
  end

  def blank?
    query.blank?
  end

  def any_results?
    illustration_count.positive? || novel_count.positive? || edition_count.positive? || illustrator_count.positive?
  end

  def matching_tags
    return [] if blank?

    @matching_tags ||= matching_tag_scope.limit(12).pluck(:name)
  end

  def illustrations
    return empty_pagination if blank?

    @illustrations ||= Kaminari.paginate_array(
      ordered_records(illustration_scope, illustration_page_ids),
      total_count: illustration_count,
      limit: ILLUSTRATIONS_PER_PAGE,
      offset: illustration_offset
    )
  end

  def illustration_count
    blank? ? 0 : ranked_count(illustration_ranked_sql)
  end

  def novels
    return [] if blank?

    @novels ||= ordered_records(novel_scope, novel_result_ids)
  end

  def novel_count
    blank? ? 0 : ranked_count(novel_ranked_sql)
  end

  def editions
    return [] if blank?

    @editions ||= ordered_records(edition_scope, edition_result_ids).reject(&:synthetic_placeholder?)
  end

  def edition_count
    blank? ? 0 : ranked_count(edition_ranked_sql)
  end

  def illustrators
    return [] if blank?

    @illustrators ||= ordered_records(illustrator_scope, illustrator_result_ids)
  end

  def illustrator_count
    blank? ? 0 : ranked_count(illustrator_ranked_sql)
  end

  private

  def illustration_scope
    Illustration.browseable.includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
  end

  def novel_scope
    Novel.publicly_visible.includes(editions: [{ cover_image_attachment: :blob }, { illustrations: { image_attachment: :blob } }])
  end

  def edition_scope
    Edition.joins(:novel).merge(Novel.publicly_visible).includes(:novel, :illustrations, cover_image_attachment: :blob)
  end

  def illustrator_scope
    Illustrator.publicly_visible.includes(illustrations: [{ image_attachment: :blob }, { edition: :novel }])
  end

  def illustration_ranked_sql
    @illustration_ranked_sql ||= ranked_sql(
      Illustration.browseable.search_all(query),
      apply_token_filters(Illustration.browseable.joins(edition: :novel).distinct, "novels.name"),
      apply_token_filters(Illustration.browseable.joins(:tags).distinct, "tags.name")
    )
  end

  def illustration_page_ids
    @illustration_page_ids ||= ranked_ids(illustration_ranked_sql, limit: ILLUSTRATIONS_PER_PAGE, offset: illustration_offset)
  end

  def novel_ranked_sql
    @novel_ranked_sql ||= ranked_sql(
      Novel.publicly_visible.search_by_name_and_description(query),
      apply_token_filters(Novel.publicly_visible.joins(:tags).distinct, "tags.name")
    )
  end

  def novel_result_ids
    @novel_result_ids ||= ranked_ids(novel_ranked_sql, limit: SECTION_LIMIT)
  end

  def edition_ranked_sql
    public_editions = Edition.joins(:novel).merge(Novel.publicly_visible).distinct

    @edition_ranked_sql ||= ranked_sql(
      Edition.search_by_name_and_publisher(query).joins(:novel).merge(Novel.publicly_visible),
      apply_token_filters_with_or(public_editions, ["novels.name", "novels.description"])
    )
  end

  def edition_result_ids
    @edition_result_ids ||= ranked_ids(edition_ranked_sql, limit: SECTION_LIMIT * 2)
  end

  def illustrator_ranked_sql
    @illustrator_ranked_sql ||= ranked_sql(
      Illustrator.publicly_visible.search_by_name_and_bio(query),
      apply_token_filters(
        Illustrator.publicly_visible.joins(illustrations: [:tags, { edition: :novel }]).distinct,
        "tags.name"
      )
    )
  end

  def illustrator_result_ids
    @illustrator_result_ids ||= ranked_ids(illustrator_ranked_sql, limit: SECTION_LIMIT)
  end

  def matching_tag_scope
    @matching_tag_scope ||= apply_token_filters(ActsAsTaggableOn::Tag.order(:name), "tags.name")
  end

  def ordered_records(scope, ids)
    return [] if ids.empty?

    records_by_id = scope.where(id: ids).index_by(&:id)
    ids.filter_map { |id| records_by_id[id] }
  end

  def ranked_sql(*relations)
    ranked_relations = relations.filter_map.with_index do |relation, rank|
      next if relation.nil?

      model = relation.klass
      selected_relation = relation
        .except(:includes, :preload, :eager_load, :select, :order)
        .reselect(Arel.sql("#{model.table_name}.id AS id, #{rank} AS match_rank"))
        .distinct

      "(#{selected_relation.to_sql})"
    end

    return if ranked_relations.empty?

    <<~SQL.squish
      SELECT ranked_matches.id, MIN(ranked_matches.match_rank) AS match_rank
      FROM (#{ranked_relations.join(' UNION ALL ')}) ranked_matches
      GROUP BY ranked_matches.id
      ORDER BY MIN(ranked_matches.match_rank) ASC, ranked_matches.id ASC
    SQL
  end

  def ranked_ids(sql, limit:, offset: 0)
    return [] if sql.blank?

    connection.select_values("#{sql} LIMIT #{limit.to_i} OFFSET #{offset.to_i}").map(&:to_i)
  end

  def ranked_count(sql)
    return 0 if sql.blank?

    connection.select_value("SELECT COUNT(*) FROM (#{sql}) ranked_match_count").to_i
  end

  def apply_token_filters(scope, column_name)
    query_tokens.reduce(scope) do |relation, token|
      relation.where("#{column_name} ILIKE ?", wildcard(token))
    end
  end

  def apply_token_filters_with_or(scope, column_names)
    query_tokens.reduce(scope) do |relation, token|
      clauses = column_names.map { |column_name| "#{column_name} ILIKE :pattern" }.join(" OR ")
      relation.where(clauses, pattern: wildcard(token))
    end
  end

  def query_tokens
    @query_tokens ||= query.scan(/[[:alnum:]]+/).presence || [query]
  end

  def wildcard(token)
    "%#{ActiveRecord::Base.sanitize_sql_like(token)}%"
  end

  def empty_pagination
    @empty_pagination ||= Kaminari.paginate_array([], total_count: 0, limit: ILLUSTRATIONS_PER_PAGE, offset: illustration_offset)
  end

  def illustration_offset
    (current_page - 1) * ILLUSTRATIONS_PER_PAGE
  end

  def current_page
    @current_page ||= [page.to_i, 1].max
  end

  def connection
    ActiveRecord::Base.connection
  end
end
