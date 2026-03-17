class HardenArchiveSchema < ActiveRecord::Migration[7.1]
  def up
    change_column_null :blog_posts, :illustration_id, true if column_exists?(:blog_posts, :illustration_id)
    change_column_null :blog_posts, :novel_id, true if column_exists?(:blog_posts, :novel_id)
    change_column_null :blog_posts, :edition_id, true if column_exists?(:blog_posts, :edition_id)

    remove_column :illustrators, :illustration_id, :integer if column_exists?(:illustrators, :illustration_id)
    drop_table :comments if table_exists?(:comments)
  end

  def down
    create_table :comments do |t|
      t.integer :user_id
      t.string :comment, limit: 255
      t.timestamps null: false
      t.integer :illustration_id
      t.boolean :is_child
      t.integer :parent_comment_id
    end unless table_exists?(:comments)

    add_column :illustrators, :illustration_id, :integer unless column_exists?(:illustrators, :illustration_id)

    change_column_null :blog_posts, :illustration_id, false if column_exists?(:blog_posts, :illustration_id)
    change_column_null :blog_posts, :novel_id, false if column_exists?(:blog_posts, :novel_id)
    change_column_null :blog_posts, :edition_id, false if column_exists?(:blog_posts, :edition_id)
  end
end
