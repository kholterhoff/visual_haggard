class CreateIllustrators < ActiveRecord::Migration[7.1]
  def change
    create_table :illustrators do |t|
      t.string :name
      t.text :bio

      t.timestamps
    end
  end
end
