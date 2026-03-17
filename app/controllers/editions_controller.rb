class EditionsController < ApplicationController
  def index
    @editions = Edition.publicly_visible
                      .includes(:novel, :blog_posts, { cover_image_attachment: :blob }, { illustrations: { image_attachment: :blob } })
                      .to_a
                      .sort_by { |edition| [edition.novel.name.downcase, edition.publication_sort_key] }
  end

  def show
    @edition = Edition.publicly_visible
                      .includes(:novel, :blog_posts, { cover_image_attachment: :blob }, { illustrations: [:illustrator, { image_attachment: :blob }] })
                      .find(params[:id])
  end
end
