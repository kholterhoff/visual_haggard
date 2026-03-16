class CreateEditions < ActiveRecord::Migration[7.1]
  def change
    create_table :editions do |t|
      t.references :novel, null: false, foreign_key: true
      t.string :name
      t.string :publisher
      t.string :publication_date
      t.string :publication_city
      t.string :source
      t.string :cover_url
      t.string :cover_thumbnail_url
      t.string :long_name
      t.string :image_file_name
      t.string :image_content_type
      t.integer :image_file_size
      t.datetime :image_updated_at

      t.timestamps
    end
  end
end
