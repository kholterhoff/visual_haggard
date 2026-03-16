class EnforceArchiveForeignKeysAndIndexes < ActiveRecord::Migration[7.1]
  def up
    cleanup_invalid_archive_rows

    add_index :editions, :novel_id unless index_exists?(:editions, :novel_id)
    add_index :illustrations, :edition_id unless index_exists?(:illustrations, :edition_id)
    add_index :illustrations, :illustrator_id unless index_exists?(:illustrations, :illustrator_id)
    add_index :blog_posts, :novel_id unless index_exists?(:blog_posts, :novel_id)
    add_index :blog_posts, :edition_id unless index_exists?(:blog_posts, :edition_id)
    add_index :blog_posts, :illustration_id unless index_exists?(:blog_posts, :illustration_id)

    add_foreign_key :editions, :novels, column: :novel_id, on_delete: :cascade unless foreign_key_exists?(:editions, :novels, column: :novel_id)
    add_foreign_key :illustrations, :editions, column: :edition_id, on_delete: :cascade unless foreign_key_exists?(:illustrations, :editions, column: :edition_id)
    add_foreign_key :illustrations, :illustrators, column: :illustrator_id, on_delete: :nullify unless foreign_key_exists?(:illustrations, :illustrators, column: :illustrator_id)
    add_foreign_key :blog_posts, :novels, column: :novel_id, on_delete: :nullify unless foreign_key_exists?(:blog_posts, :novels, column: :novel_id)
    add_foreign_key :blog_posts, :editions, column: :edition_id, on_delete: :nullify unless foreign_key_exists?(:blog_posts, :editions, column: :edition_id)
    add_foreign_key :blog_posts, :illustrations, column: :illustration_id, on_delete: :nullify unless foreign_key_exists?(:blog_posts, :illustrations, column: :illustration_id)
  end

  def down
    remove_foreign_key :blog_posts, column: :illustration_id if foreign_key_exists?(:blog_posts, column: :illustration_id)
    remove_foreign_key :blog_posts, column: :edition_id if foreign_key_exists?(:blog_posts, column: :edition_id)
    remove_foreign_key :blog_posts, column: :novel_id if foreign_key_exists?(:blog_posts, column: :novel_id)
    remove_foreign_key :illustrations, column: :illustrator_id if foreign_key_exists?(:illustrations, column: :illustrator_id)
    remove_foreign_key :illustrations, column: :edition_id if foreign_key_exists?(:illustrations, column: :edition_id)
    remove_foreign_key :editions, column: :novel_id if foreign_key_exists?(:editions, column: :novel_id)

    remove_index :blog_posts, :illustration_id if index_exists?(:blog_posts, :illustration_id)
    remove_index :blog_posts, :edition_id if index_exists?(:blog_posts, :edition_id)
    remove_index :blog_posts, :novel_id if index_exists?(:blog_posts, :novel_id)
    remove_index :illustrations, :illustrator_id if index_exists?(:illustrations, :illustrator_id)
    remove_index :illustrations, :edition_id if index_exists?(:illustrations, :edition_id)
    remove_index :editions, :novel_id if index_exists?(:editions, :novel_id)
  end

  private

  def cleanup_invalid_archive_rows
    execute <<~SQL.squish
      DELETE FROM illustrations
      WHERE edition_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM editions
          WHERE editions.id = illustrations.edition_id
        )
    SQL

    execute <<~SQL.squish
      UPDATE blog_posts
      SET novel_id = NULL
      WHERE novel_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM novels
          WHERE novels.id = blog_posts.novel_id
        )
    SQL

    execute <<~SQL.squish
      UPDATE blog_posts
      SET edition_id = NULL
      WHERE edition_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM editions
          WHERE editions.id = blog_posts.edition_id
        )
    SQL

    execute <<~SQL.squish
      UPDATE blog_posts
      SET illustration_id = NULL
      WHERE illustration_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM illustrations
          WHERE illustrations.id = blog_posts.illustration_id
        )
    SQL
  end
end
