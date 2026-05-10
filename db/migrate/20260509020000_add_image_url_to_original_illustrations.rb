class AddImageUrlToOriginalIllustrations < ActiveRecord::Migration[7.1]
  def change
    add_column :original_illustrations, :image_url, :string
  end
end
