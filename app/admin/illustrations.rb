ActiveAdmin.register Illustration do
  permit_params :name,
                :artist,
                :image_url,
                :image_thumbnail_url,
                :description,
                :edition_id,
                :illustrator_id,
                :page_number,
                :google_book_link,
                :gutenberg_link,
                :internet_archive_link,
                :is_same_google_edition,
                :is_same_gutenberg_edition,
                :is_same_internet_archive_edition,
                :tag_list,
                :image

  includes :illustrator, { edition: :novel }, image_attachment: :blob
  config.filters = false

  member_action :update_sibling_groupings, method: :patch do
    unless Illustration.identical_image_group_supported?
      redirect_to resource_path, alert: "Variant illustration grouping is unavailable until the latest database migration is applied."
      next
    end

    selected_ids = params.fetch(:identical_grouping, {})
                        .select { |_illustration_id, value| value == "same" }
                        .keys

    resource.assign_identical_siblings_from_novel!(selected_ids)

    redirect_to resource_path, notice: "Variant illustration selections saved."
  end

  index do
    selectable_column
    id_column
    column :name
    column :edition
    column :illustrator
    column :page_number
    column("Image") { |illustration| status_tag(illustration.display_image_source(style: :original).present? ? "yes" : "no") }
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :artist
      row :edition
      row("Novel") { |illustration| illustration.edition&.novel }
      row :illustrator
      row :page_number
      row :description
      row :tag_list
      row :image_url
      row :image_thumbnail_url
      row :identical_image_group if Illustration.identical_image_group_supported?
      row :google_book_link
      row :gutenberg_link
      row :internet_archive_link
      row("Image source") { |illustration| illustration.display_image_source(style: :original) }
      row :created_at
      row :updated_at
    end

    if resource.display_image_source(style: :original).present?
      panel "Image preview" do
        image_tag resource.display_image_source(style: :original), style: "max-width: 320px; max-height: 300px; width: auto; height: auto;"
      end
    end

    panel "Other illustrations from #{resource.novel.name}" do
      related_illustrations = resource.other_illustrations_from_novel
                                     .includes(:edition, image_attachment: :blob)
                                     .to_a
                                     .sort_by do |illustration|
        [
          resource.grouped_with?(illustration) ? 0 : 1,
          illustration.edition.publication_sort_key,
          illustration.id
        ]
      end

      if Illustration.identical_image_group_supported?
        render partial: "admin/illustrations/related_novel_illustrations",
               locals: { current_illustration: resource, illustrations: related_illustrations }
      else
        para "Variant illustration controls will appear here after the database migration for this feature has been applied."
      end
    end
  end

  form html: { multipart: true } do |f|
    f.semantic_errors

    f.inputs "Illustration details" do
      f.input :edition, collection: Edition.includes(:novel).order(:id).map { |edition| ["#{edition.novel.name} - #{edition.display_title}", edition.id] }
      f.input :illustrator, collection: Illustrator.order(:name)
      f.input :name
      f.input :artist
      f.input :page_number
      f.input :description, input_html: { rows: 8 }
      f.input :tag_list,
              input_html: { value: f.object.tag_list.join(", ") },
              hint: "Comma-separated keywords used by archive search."
    end

    f.inputs "Image" do
      f.input :image,
              as: :file,
              hint: (
                if f.object.display_image_source(style: :original).present?
                  image_tag(f.object.display_image_source(style: :original), style: "max-width: 220px; height: auto;")
                else
                  "Upload a new illustration image. Uploaded files override legacy image URLs on the public site."
                end
              )
      f.input :image_url, hint: "Optional external or legacy original image URL."
      f.input :image_thumbnail_url, hint: "Optional external or legacy thumbnail URL."
    end

    f.inputs "Source links" do
      f.input :google_book_link
      f.input :gutenberg_link
      f.input :internet_archive_link
      f.input :is_same_google_edition
      f.input :is_same_gutenberg_edition
      f.input :is_same_internet_archive_edition
    end

    f.actions
  end
end
