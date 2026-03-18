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
    @illustration_groups = @illustrations
                           .select { |illustration| illustration.edition.present? && illustration.edition.novel.present? }
                           .group_by { |illustration| illustration.edition.novel }
                           .map do |novel, illustrations|
      {
        novel:,
        anchor_id: "illustrator-work-novel-#{novel.id}",
        illustrations: illustrations.sort_by do |illustration|
          [illustration.edition.publication_sort_key, illustration.edition.id, illustration.id]
        end
      }
    end
                           .sort_by { |group| group[:novel].directory_sort_key }
  end
end
