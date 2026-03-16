class CreateBlogPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :blog_posts do |t|
      t.string :author
      t.string :title
      t.text :content
      t.references :illustration, null: false, foreign_key: true
      t.references :novel, null: false, foreign_key: true
      t.references :edition, null: false, foreign_key: true

      t.timestamps
    end
  end
end
