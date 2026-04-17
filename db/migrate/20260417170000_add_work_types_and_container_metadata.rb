class AddWorkTypesAndContainerMetadata < ActiveRecord::Migration[7.1]
  SHORT_STORY_NAMES = [
    "Hunter Quatermain's Story",
    "A Tale of Three Lions",
    "Long Odds",
    "Magepa the Buck",
    "Suggested Prologue to a Dramatized Version of \"She\""
  ].freeze

  EDITION_CONTAINERS = {
    59 => { container_title: "Princess Mary's Gift Book", container_type: "book" },
    85 => { container_title: "In a Good Cause", container_type: "book" },
    186 => { container_title: "Allan's Wife And Other Tales", container_type: "book" },
    187 => { container_title: "Allan's Wife And Other Tales", container_type: "book" },
    189 => { container_title: "Allan's Wife And Other Tales", container_type: "book" },
    199 => { container_title: "Atalanta Magazine", container_type: "periodical" },
    200 => { container_title: "Atalanta Magazine", container_type: "periodical" },
    201 => { container_title: "Atalanta Magazine", container_type: "periodical" },
    464 => { container_title: "Harper's Weekly", container_type: "periodical" },
    553 => { container_title: "Allan's Wife And Other Tales", container_type: "book" },
    554 => { container_title: "Allan's Wife And Other Tales", container_type: "book" },
    555 => { container_title: "Allan's Wife And Other Tales", container_type: "book" }
  }.freeze

  class MigrationNovel < ActiveRecord::Base
    self.table_name = "novels"
  end

  class MigrationEdition < ActiveRecord::Base
    self.table_name = "editions"
  end

  def up
    add_column :novels, :work_type, :string, default: "novel", null: false
    add_column :editions, :container_title, :string
    add_column :editions, :container_type, :string

    MigrationNovel.reset_column_information
    MigrationEdition.reset_column_information

    say_with_time "Mark short story records" do
      MigrationNovel.where(name: SHORT_STORY_NAMES).update_all(work_type: "short_story", updated_at: Time.current)
    end

    say_with_time "Populate host publication metadata for short story editions" do
      EDITION_CONTAINERS.each do |edition_id, attributes|
        MigrationEdition.where(id: edition_id).update_all(attributes.merge(updated_at: Time.current))
      end
    end
  end

  def down
    remove_column :editions, :container_type
    remove_column :editions, :container_title
    remove_column :novels, :work_type
  end
end
