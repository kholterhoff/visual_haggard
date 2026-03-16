class CreateIllustrations < ActiveRecord::Migration[7.1]
  def change
    create_table :illustrations do |t|
      t.string :name
      t.string :artist
      t.string :image_url
      t.string :image_thumbnail_url
      t.text :description
      t.references :edition, null: false, foreign_key: true
      t.references :illustrator, null: false, foreign_key: true
      t.integer :tagging_id
      t.string :page_number
      t.string :google_book_link
      t.string :gutenberg_link
      t.string :internet_archive_link
      t.boolean :is_same_google_edition
      t.boolean :is_same_gutenberg_edition
      t.boolean :is_same_internet_archive_edition
      t.string :image_file_name
      t.string :image_content_type
      t.integer :image_file_size
      t.datetime :image_updated_at

      t.timestamps
    end
  end
end
