class IllustratorsController < ApplicationController
  def index
    @illustrators = Illustrator.publicly_visible
                               .includes(illustrations: [{ image_attachment: :blob }, { edition: :novel }])
                               .to_a
                               .reject(&:synthetic_placeholder?)
                               .sort_by(&:directory_sort_key)
    @illustrator_groups = @illustrators.group_by(&:directory_letter)
  end

  def show
    @illustrator = Illustrator.publicly_visible.includes(illustrations: [{ image_attachment: :blob }, { edition: :novel }]).find(params[:id])
    @illustrations = @illustrator.illustrations
                                 .browseable
                                 .includes(image_attachment: :blob, edition: :novel)
                                 .order(:id)
    raise ActiveRecord::RecordNotFound if @illustrator.synthetic_placeholder?
  end
end
