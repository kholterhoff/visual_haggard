class EditionsController < ApplicationController
  def index
    @editions = Edition.publicly_visible
                      .includes(:novel, :blog_posts, { cover_image_attachment: :blob }, { illustrations: { image_attachment: :blob } })
                      .order("novels.name ASC, editions.publication_date ASC")
  end

  def show
    @edition = Edition.publicly_visible
                      .includes(:novel, :blog_posts, { cover_image_attachment: :blob }, { illustrations: [:illustrator, { image_attachment: :blob }] })
                      .find(params[:id])
  end
end
