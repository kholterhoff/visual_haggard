ActiveAdmin.register OriginalIllustration do
  permit_params :novel_id,
                :illustrator_id,
                :title,
                :dimensions,
                :medium,
                :source,
                :year,
                :image_url

  includes :novel, :illustrator
  config.filters = false

  index do
    selectable_column
    id_column
    column :novel
    column :illustrator
    column :title
    column("Image") { |orig| status_tag(orig.display_image_source.present? ? "yes" : "no") }
    actions
  end

  show do
    attributes_table do
      row :id
      row :novel
      row :illustrator
      row :title
      row :year
      row :medium
      row :dimensions
      row :source
      row :image_url
      row :created_at
      row :updated_at
    end

    if resource.display_image_source.present?
      panel "Image preview" do
        image_tag resource.display_image_source, style: "max-width: 320px; max-height: 300px; width: auto; height: auto;"
      end
    end

    panel "Printed illustrations linked to this artwork" do
      linked = resource.illustrations.includes(:edition).order(:id).to_a

      if linked.any?
        safe_join(linked.map do |illustration|
          details = [illustration.edition.display_title, illustration.page_number.presence].compact.join(" | ")

          content_tag(:div, class: "admin-illustration-group-summary") do
            safe_join([
              link_to(illustration.name, admin_illustration_path(illustration)),
              content_tag(:div, details, class: "admin-illustration-group-summary-meta")
            ])
          end
        end)
      else
        para "No printed illustrations are linked to this original artwork yet. Link them from each illustration's admin page."
      end
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs "Original artwork details" do
      grouped_novel_options = Novel.publicly_visible.to_a.sort_by(&:directory_sort_key).map { |n| [n.name, n.id] }

      f.input :novel_id,
              as: :select,
              collection: grouped_novel_options,
              include_blank: false,
              label: "Novel"
      f.input :illustrator, collection: Illustrator.order(:name)
      f.input :title, hint: "Optional title of the artwork."
      f.input :year, hint: "Optional year the artwork was created."
      f.input :medium, hint: "E.g. Oil on canvas, watercolor, pencil."
      f.input :dimensions, hint: "E.g. 24 × 36 cm."
      f.input :source, hint: "Where the scan or image came from."
    end

    f.inputs "Image" do
      f.input :image_url, label: "Image URL", hint: "Paste the URL of the image."
    end

    f.actions
  end
end
