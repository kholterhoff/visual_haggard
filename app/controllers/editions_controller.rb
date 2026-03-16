class EditionsController < ApplicationController
  def index
    @editions = Edition.includes(:novel, :blog_posts, { cover_image_attachment: :blob }, { illustrations: { image_attachment: :blob } })
                      .order('novels.name ASC, editions.publication_date ASC')
                      .reject(&:synthetic_placeholder?)
  end

  def show
    @edition = Edition.includes(:novel, :blog_posts, { cover_image_attachment: :blob }, { illustrations: [:illustrator, { image_attachment: :blob }] }).find(params[:id])
    raise ActiveRecord::RecordNotFound if @edition.synthetic_placeholder?
  end
end
