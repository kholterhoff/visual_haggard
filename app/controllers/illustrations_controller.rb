class IllustrationsController < ApplicationController
  def index
    scope = Illustration.joins(edition: :novel)
                        .includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
                        .order(:id)
    scope = scope.where(edition_id: params[:edition_id]) if params[:edition_id].present?
    @illustrations = scope
  end

  def show
    @illustration = Illustration.joins(edition: :novel)
                                .includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
                                .find(params[:id])
  end
end
