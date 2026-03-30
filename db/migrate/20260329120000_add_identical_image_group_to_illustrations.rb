class AddIdenticalImageGroupToIllustrations < ActiveRecord::Migration[7.1]
  def change
    add_column :illustrations, :identical_image_group, :string
    add_index :illustrations, :identical_image_group
  end
end
