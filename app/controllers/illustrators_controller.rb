class IllustratorsController < ApplicationController
  def index
    @illustrators = Illustrator.includes(illustrations: [{ image_attachment: :blob }, { edition: :novel }]).to_a.sort_by(&:directory_sort_key)
    @illustrator_groups = @illustrators.group_by(&:directory_letter)
  end

  def show
    @illustrator = Illustrator.includes(illustrations: [{ image_attachment: :blob }, { edition: :novel }]).find(params[:id])
    @illustrations = @illustrator.illustrations
                                 .browseable
                                 .includes(image_attachment: :blob, edition: :novel)
                                 .order(:id)
  end
end
