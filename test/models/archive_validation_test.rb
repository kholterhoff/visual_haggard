require "test_helper"

class ArchiveValidationTest < ActiveSupport::TestCase
  test "blog posts remain valid without attached archive records" do
    blog_post = BlogPost.new(title: "Archive note", content: "Editorial copy")

    assert_predicate blog_post, :valid?
  end

  test "edition allows legacy cover references but rejects dangerous schemes" do
    novel = Novel.create!(name: "Validation Novel")

    edition = Edition.new(novel: novel, name: "Validation Edition", cover_url: "legacy-cover.jpg")
    assert_predicate edition, :valid?

    edition.cover_url = "javascript:alert(1)"
    assert_not edition.valid?
    assert_includes edition.errors[:cover_url], "must be a valid http:// or https:// URL or legacy file reference"
  end

  test "illustration source links require http or https" do
    novel = Novel.create!(name: "Validation Novel")
    edition = Edition.create!(novel: novel, name: "Validation Edition")

    illustration = Illustration.new(
      edition: edition,
      name: "Validation Illustration",
      image_url: "legacy-image.jpg",
      google_book_link: "javascript:alert(1)"
    )

    assert_not illustration.valid?
    assert_includes illustration.errors[:google_book_link], "must be a valid http:// or https:// URL"

    illustration.google_book_link = "https://books.example.test/item"
    assert_predicate illustration, :valid?
  end

  test "illustration page labels remain freeform archive metadata" do
    novel = Novel.create!(name: "Validation Novel")
    edition = Edition.create!(novel: novel, name: "Validation Edition")
    illustration = Illustration.new(edition: edition, name: "Front matter", page_number: "Dust Jacket")

    assert_predicate illustration, :valid?
  end

  test "string length validations mirror database-backed limits" do
    novel = Novel.create!(name: "Validation Novel")
    edition = Edition.new(novel: novel, name: "A" * 256)

    assert_not edition.valid?
    assert_includes edition.errors[:name], "is too long (maximum is 255 characters)"
  end

  test "novel short titles follow the archive override rules" do
    overrides = {
      "Allan and the Holy Flower [The Holy Flower]" => "Allan and the Holy Flower",
      "Benita [The Spirit of Bambatse]" => "Benita",
      "Fair Margaret [Margaret]" => "Fair Margaret",
      "Lysbeth, A Tale of the Dutch" => "Lysbeth",
      "Pearl-Maiden: A Tale of the Fall of Jerusalem" => "Pearl-Maiden",
      "Maiwa's Revenge; Or, The War of the Little Hand" => "Maiwa's Revenge",
      "The Mahatma and the Hare, A Dream Story" => "The Mahatma and the Hare",
      "She, A History of Adventure" => "She"
    }

    overrides.each do |long_title, short_title|
      novel = Novel.new(name: long_title)
      assert_equal short_title, novel.short_title
      assert_equal long_title, novel.long_title
    end
  end
end
