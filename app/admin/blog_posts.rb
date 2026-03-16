ActiveAdmin.register BlogPost do
  permit_params :author, :title, :content, :illustration_id, :novel_id, :edition_id

  includes :illustration, :novel, :edition

  index do
    selectable_column
    id_column
    column :title
    column :author
    column :novel
    column :edition
    column :illustration
    column :created_at
    actions
  end

  filter :title
  filter :author
  filter :novel
  filter :edition
  filter :illustration
  filter :created_at

  show do
    attributes_table do
      row :id
      row :title
      row :author
      row :novel
      row :edition
      row :illustration
      row :content
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors

    f.inputs do
      f.input :title
      f.input :author
      f.input :novel, collection: Novel.order(:name)
      f.input :edition, collection: Edition.includes(:novel).order(:id).map { |edition| ["#{edition.novel.name} - #{edition.display_title}", edition.id] }
      f.input :illustration, collection: Illustration.includes(edition: :novel).order(:id).map { |illustration| ["#{illustration.edition.novel.name} - #{illustration.name}", illustration.id] }
      f.input :content, input_html: { rows: 16 }
    end

    f.actions
  end
end
