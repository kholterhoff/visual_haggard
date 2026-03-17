require "test_helper"

class ArchiveIntegrityTest < ActiveSupport::TestCase
  test "illustrations require a valid edition at the database layer" do
    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      Illustration.connection.execute <<~SQL
        INSERT INTO illustrations (name, edition_id, created_at, updated_at)
        VALUES ('Broken illustration', 999999, NOW(), NOW())
      SQL
    end

    assert_match(/foreign key/i, error.message)
  end

  test "representative illustration does not issue extra queries when preloaded" do
    novel = Novel.create!(name: "Preloaded Query Novel")
    edition = novel.editions.create!(name: "Preloaded Query Edition")
    illustrator = Illustrator.create!(name: "Preloaded Query Illustrator")
    illustration = edition.illustrations.create!(
      name: "Representative work",
      illustrator: illustrator,
      image_url: "https://example.com/representative.jpg"
    )

    preloaded_illustrator = Illustrator.includes(illustrations: [{ image_attachment: :blob }, { edition: [:novel, { cover_image_attachment: :blob }] }]).find(illustrator.id)

    queries = capture_sql_queries do
      assert_equal illustration.id, preloaded_illustrator.representative_illustration.id
    end

    assert_equal 0, queries.size
  end

  test "lead illustration does not issue extra queries when preloaded" do
    novel = Novel.create!(name: "Lead Illustration Novel")
    edition = novel.editions.create!(name: "Lead Illustration Edition")
    illustration = edition.illustrations.create!(
      name: "Lead illustration",
      image_url: "https://example.com/lead-illustration.jpg"
    )

    preloaded_novel = Novel.includes(editions: [:blog_posts, { illustrations: :image_attachment }]).find(novel.id)

    queries = capture_sql_queries do
      assert_equal illustration.id, preloaded_novel.lead_illustration.id
    end

    assert_equal 0, queries.size
  end

  test "placeholder archive records are excluded from public scopes" do
    novel = Novel.create!(name: "Illustrator Novel")
    edition = novel.editions.create!(name: "Illustrator Edition")
    illustrator = Illustrator.create!(name: "Efficient Illustrator")
    illustration = edition.illustrations.create!(
      name: "Representative illustration",
      illustrator: illustrator,
      image_url: "https://example.com/representative.jpg"
    )

    assert novel.synthetic_placeholder?
    assert edition.synthetic_placeholder?
    assert illustration.test_placeholder?
    assert illustrator.synthetic_placeholder?

    assert_not_includes Novel.publicly_visible.to_a, novel
    assert_not_includes Edition.publicly_visible.to_a, edition
    assert_not_includes Illustration.browseable.to_a, illustration
    assert_not_includes Illustrator.publicly_visible.to_a, illustrator
  end
end
