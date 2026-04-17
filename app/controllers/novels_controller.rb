class NovelsController < ApplicationController
  def index
    @novels = Novel.publicly_visible.includes(
      editions: [
        :blog_posts,
        :cover_image_attachment,
        { illustrations: [:illustrator, :image_attachment] }
      ]
    ).order(:name).page(params[:page]).per(Novel::ARCHIVE_PAGE_SIZE)

    @novel_directory = Novel.publicly_visible.select(:id, :name, :work_type).to_a.sort_by(&:directory_sort_key)
    @novel_groups = @novel_directory.group_by(&:directory_letter)
  end

  def show
    @novel = Novel.includes(
      :blog_posts,
      editions: [
        :blog_posts,
        :cover_image_attachment,
        { illustrations: [:illustrator, :image_attachment] }
      ]
    ).find(params[:id])
    raise ActiveRecord::RecordNotFound if @novel.synthetic_placeholder?
  end
end
