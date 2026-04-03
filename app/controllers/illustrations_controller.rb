class IllustrationsController < ApplicationController
  def index
    scope = Illustration.browseable
                        .includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
                        .order(:id)
    scope = scope.where(edition_id: params[:edition_id]) if params[:edition_id].present?
    @illustrations = scope
  end

  def show
    grouped_scope = Illustration.browseable
                                .includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
    @illustration = Illustration.browseable
                                .includes(:illustrator, { edition: :novel }, { image_attachment: :blob })
                                .find(params[:id])
    @identical_illustrations = if Illustration.identical_image_group_supported?
      sort_related_illustrations(@illustration.other_identical_illustrations(grouped_scope))
    else
      []
    end
    @same_moment_illustrations = if Illustration.text_moment_group_supported?
      scene_illustrations = sort_related_illustrations(@illustration.other_text_moment_illustrations(grouped_scope))
      variant_ids = @identical_illustrations.each_with_object({}) do |illustration, ids|
        ids[illustration.id] = true
      end
      scene_illustrations.reject { |illustration| variant_ids.include?(illustration.id) }
    else
      []
    end
  end

  private

  def sort_related_illustrations(scope)
    scope.to_a.sort_by do |illustration|
      [
        illustration.novel == @illustration.novel ? 0 : 1,
        illustration.novel.directory_sort_key,
        illustration.edition.publication_sort_key,
        illustration.id
      ]
    end
  end
end
