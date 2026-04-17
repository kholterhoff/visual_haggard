class AddEditorNotesToIllustrations < ActiveRecord::Migration[7.1]
  def change
    add_column :illustrations, :editor_notes, :text
  end
end
