class CreateOriginalIllustrations < ActiveRecord::Migration[7.1]
  def change
    create_table :original_illustrations do |t|
      t.references :novel, null: false, foreign_key: true
      t.string :artist, null: false
      t.string :title
      t.string :dimensions
      t.string :medium
      t.string :source
      t.string :year

      t.timestamps
    end

    add_reference :illustrations, :original_illustration, foreign_key: true
  end
end
