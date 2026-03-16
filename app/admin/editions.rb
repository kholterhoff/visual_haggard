ActiveAdmin.register Edition do
  permit_params :novel_id,
                :name,
                :publisher,
                :publication_date,
                :publication_city,
                :source,
                :cover_url,
                :cover_thumbnail_url,
                :long_name,
                :cover_image

  includes :novel, :illustrations, cover_image_attachment: :blob
  config.filters = false

  index do
    selectable_column
    id_column
    column :novel
    column :name
    column :publication_date
    column :publisher
    column("Cover") { |edition| status_tag(edition.display_cover_source(style: :original).present? ? "yes" : "no") }
    column("Illustrations") { |edition| edition.illustrations.size }
    actions
  end

  show do
    attributes_table do
      row :id
      row :novel
      row :name
      row :long_name
      row :publisher
      row :publication_date
      row :publication_city
      row :source
      row :cover_url
      row :cover_thumbnail_url
      row("Cover source") { |edition| edition.display_cover_source(style: :original) }
      row("Illustrations") { |edition| edition.illustrations.size }
      row :created_at
      row :updated_at
    end

    if resource.display_cover_source(style: :original).present?
      panel "Cover preview" do
        image_tag resource.display_cover_source(style: :original), style: "max-width: 320px; height: auto;"
      end
    end
  end

  form html: { multipart: true } do |f|
    f.semantic_errors

    f.inputs "Edition details" do
      f.input :novel, collection: Novel.order(:name)
      f.input :name
      f.input :long_name
      f.input :publisher
      f.input :publication_date
      f.input :publication_city
      f.input :source
    end

    f.inputs "Cover image" do
      f.input :cover_image,
              as: :file,
              hint: (
                if f.object.display_cover_source(style: :original).present?
                  image_tag(f.object.display_cover_source(style: :original), style: "max-width: 220px; height: auto;")
                else
                  "Upload a new cover image. Uploaded files override legacy cover URLs on the public site."
                end
              )
      f.input :cover_url, hint: "Optional external or legacy image URL."
      f.input :cover_thumbnail_url, hint: "Optional thumbnail URL for legacy records."
    end

    f.actions
  end
end
