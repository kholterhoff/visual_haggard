class AddTextMomentGroupToIllustrations < ActiveRecord::Migration[7.1]
  def change
    add_column :illustrations, :text_moment_group, :string
    add_index :illustrations, :text_moment_group
  end
end
