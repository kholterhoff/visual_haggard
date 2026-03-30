class IllustrationsController < ApplicationController
  def index
    scope = Illustration.browseable
                        .includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
                        .order(:id)
    scope = scope.where(edition_id: params[:edition_id]) if params[:edition_id].present?
    @illustrations = scope
  end

  def show
    @illustration = Illustration.browseable
                                .includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
                                .find(params[:id])
    @identical_illustrations = if Illustration.identical_image_group_supported?
      @illustration.other_identical_illustrations(
        Illustration.browseable
                    .includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
      ).to_a.sort_by do |illustration|
        [
          illustration.novel == @illustration.novel ? 0 : 1,
          illustration.novel.directory_sort_key,
          illustration.edition.publication_sort_key,
          illustration.id
        ]
      end
    else
      []
    end
  end
end
