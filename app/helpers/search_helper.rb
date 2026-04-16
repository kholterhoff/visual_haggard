module SearchHelper
  SEARCH_ILLUSTRATION_GROUPING_CONFIG = {
    novel: {
      tab_label: "By novel",
      eyebrow: "Novel"
    },
    edition: {
      tab_label: "By edition",
      eyebrow: "Edition"
    },
    illustrator: {
      tab_label: "By illustrator",
      eyebrow: "Illustrator"
    }
  }.freeze

  def search_illustration_groupings(illustrations)
    records = Array(illustrations).filter_map do |illustration|
      edition = illustration.edition
      novel = edition&.novel
      next if edition.blank? || novel.blank?

      {
        illustration: illustration,
        novel: novel,
        edition: edition,
        illustrator_name: illustration.illustrator&.name.presence || illustration.artist.presence || "Unknown illustrator"
      }
    end

    groups = {
      novel: build_search_illustration_groups(records, :novel),
      edition: build_search_illustration_groups(records, :edition),
      illustrator: build_search_illustration_groups(records, :illustrator)
    }

    visible_groupings = SEARCH_ILLUSTRATION_GROUPING_CONFIG.keys.select { |grouping| groups[grouping].size > 1 }
    default_grouping =
      if visible_groupings.include?(:novel) || visible_groupings.empty?
        :novel
      else
        visible_groupings.first
      end

    {
      groups: groups,
      visible_groupings: visible_groupings,
      default_grouping: default_grouping
    }
  end

  def search_illustration_grouping_tab_label(grouping)
    search_illustration_grouping_config(grouping)[:tab_label]
  end

  def search_illustration_grouping_eyebrow(grouping)
    search_illustration_grouping_config(grouping)[:eyebrow]
  end

  private

  def build_search_illustration_groups(records, grouping)
    records.each_with_object({}) do |record, groups|
      group_key, group_data =
        case grouping
        when :novel
          [
            "novel-#{record[:novel].id}",
            {
              novel: record[:novel]
            }
          ]
        when :edition
          [
            "edition-#{record[:edition].id}",
            {
              edition: record[:edition],
              novel: record[:novel],
              title: condensed_edition_label(record[:edition], novel: record[:novel]).presence || record[:edition].display_title
            }
          ]
        when :illustrator
          [
            "illustrator-#{record[:illustration].illustrator_id || record[:illustrator_name]}",
            {
              title: record[:illustrator_name]
            }
          ]
        end

      groups[group_key] ||= group_data.merge(illustrations: [])
      groups[group_key][:illustrations] << record[:illustration]
    end.values
  end

  def search_illustration_grouping_config(grouping)
    SEARCH_ILLUSTRATION_GROUPING_CONFIG.fetch(grouping.to_sym)
  end
end
