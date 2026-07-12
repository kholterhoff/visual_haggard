class IllustratorsController < ApplicationController
  def index
    @illustrators = Illustrator.publicly_visible
                               .includes(illustrations: [{ image_attachment: :blob }, { edition: [:novel, { cover_image_attachment: :blob }] }])
                               .sort_by(&:directory_sort_key)
    @illustrator_groups = @illustrators.group_by(&:directory_letter)
  end

  def show
    @illustrator = Illustrator.publicly_visible
                              .includes(illustrations: [{ image_attachment: :blob }, { edition: [:novel, { cover_image_attachment: :blob }] }])
                              .find(params[:id])
    @illustrations = @illustrator.illustrations
                                 .browseable
                                 .includes(image_attachment: :blob, edition: :novel)
                                 .order(:id)

    originals_by_novel = @illustrator.original_illustrations
                                     .includes(:novel)
                                     .to_a
                                     .group_by(&:novel)

    printed_by_novel = @illustrations
                         .select { |i| i.edition.present? && i.edition.novel.present? }
                         .group_by { |i| i.edition.novel }

    all_novels = (originals_by_novel.keys + printed_by_novel.keys).uniq

    @illustration_groups = all_novels.map do |novel|
      originals = (originals_by_novel[novel] || []).sort_by(&:display_title)
      printed = (printed_by_novel[novel] || []).sort_by do |illustration|
        [illustration.edition.publication_sort_key, illustration.edition.id, illustration.id]
      end
      {
        novel:,
        anchor_id: "illustrator-work-novel-#{novel.id}",
        original_illustrations: originals,
        illustrations: printed
      }
    end.sort_by { |group| group[:novel].directory_sort_key }
  end
end
