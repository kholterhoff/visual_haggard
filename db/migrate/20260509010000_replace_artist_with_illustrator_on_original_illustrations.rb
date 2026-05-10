class ReplaceArtistWithIllustratorOnOriginalIllustrations < ActiveRecord::Migration[7.1]
  def change
    add_reference :original_illustrations, :illustrator, foreign_key: true
    remove_column :original_illustrations, :artist, :string, null: false
  end
end
