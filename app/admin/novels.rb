ActiveAdmin.register Novel do
  permit_params :name, :work_type, :description, :tag_list

  includes :editions, :illustrations
  remove_filter :base_tags
  remove_filter :tag_taggings
  remove_filter :taggings
  filter :name
  filter :description
  filter :created_at
  filter :updated_at

  index do
    selectable_column
    id_column
    column :name
    column :work_type
    column("Editions") { |novel| novel.editions.size }
    column("Illustrations") { |novel| novel.illustrations.size }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :work_type
      row :description
      row :tag_list
      row("Editions") { |novel| novel.editions.size }
      row("Illustrations") { |novel| novel.illustrations.size }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs do
      f.input :name
      f.input :work_type,
              as: :select,
              collection: Novel::WORK_TYPES.map { |value| [value.humanize, value] },
              include_blank: false
      f.input :description, input_html: { rows: 12 }
      f.input :tag_list,
              input_html: { value: f.object.tag_list.join(", ") },
              hint: "Comma-separated keywords."
    end

    f.actions
  end
end
