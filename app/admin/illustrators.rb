ActiveAdmin.register Illustrator do
  permit_params :name, :bio

  includes :illustrations
  filter :name
  filter :bio
  filter :created_at
  filter :updated_at

  index do
    selectable_column
    id_column
    column :name
    column("Illustrations") { |illustrator| illustrator.illustrations.size }
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :bio
      row("Illustrations") { |illustrator| illustrator.illustrations.size }
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs do
      f.input :name
      f.input :bio, input_html: { rows: 12 }
    end

    f.actions
  end
end
