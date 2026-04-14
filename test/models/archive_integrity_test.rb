require "test_helper"

class ArchiveIntegrityTest < ActiveSupport::TestCase
  test "public stylesheet manifest stays explicit and excludes active admin" do
    manifest = Rails.root.join("app/assets/stylesheets/application.css").read

    assert_includes manifest, "require layout"
    assert_includes manifest, "require home"
    refute_match(/require_tree\s+\./, manifest)
    refute_match(/require(?:_self)?\s+active_admin|active_admin/, manifest)
  end

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

  test "representative grid image prefers edition cover art for cover-like works" do
    novel = Novel.create!(name: "Cover Query Novel")
    edition = novel.editions.create!(name: "Cover Query Edition", cover_url: "https://example.com/cover.jpg")
    illustrator = Illustrator.create!(name: "Cover Query Illustrator")
    illustration = edition.illustrations.create!(
      name: "Cover design",
      illustrator: illustrator,
      image_url: "https://example.com/interior.jpg"
    )

    assert_equal illustration.id, illustrator.representative_illustration.id
    assert_equal "https://example.com/cover.jpg", illustrator.representative_grid_image_source
  end

  test "illustrator cover carousel includes book-edition covers when illustrator has strong edition presence" do
    illustrator = Illustrator.create!(name: "Edition Cover Illustrator")
    novel = Novel.create!(name: "Edition Cover Novel")
    edition = novel.editions.create!(name: "Edition with Cover", cover_url: "https://example.com/edition-cover.jpg")
    illustration = edition.illustrations.create!(
      name: "Frontispiece illustration",
      illustrator:,
      page_number: "Frontispiece",
      image_url: "https://example.com/interior-scene.jpg"
    )

    entries = illustrator.cover_carousel_entries

    assert_equal 1, entries.size
    assert_equal illustration.id, entries.first[:illustration].id
    assert_equal edition.id, entries.first[:edition].id
    assert_equal "https://example.com/edition-cover.jpg", entries.first[:source]
  end

  test "illustrator cover carousel excludes periodical edition covers when illustrator only has interior illustrations" do
    illustrator = Illustrator.create!(name: "Periodical Illustrator")
    novel = Novel.create!(name: "Serialized Novel")
    edition = novel.editions.create!(
      name: "The Windsor Magazine, vol. 21",
      publisher: "George Newnes",
      cover_url: "https://example.com/windsor-cover.jpg"
    )
    edition.illustrations.create!(
      name: "Interior scene",
      illustrator:,
      page_number: "Facing page 18",
      image_url: "https://example.com/interior-scene.jpg"
    )

    entries = illustrator.cover_carousel_entries

    assert_empty entries
  end

  test "novel cover carousel entries use cover and dust jacket sources and cap at five" do
    novel = Novel.create!(name: "Carousel Novel")
    first = novel.editions.create!(name: "1910 Edition", publication_date: "1910", cover_url: "https://example.com/1910-cover.jpg")
    second = novel.editions.create!(name: "1911 Edition", publication_date: "1911")
    second_dust_jacket = second.illustrations.create!(
      name: "1911 Dust Jacket",
      page_number: "Dust Jacket",
      image_url: "https://example.com/1911-dust-jacket.jpg"
    )
    third = novel.editions.create!(name: "1912 Edition", publication_date: "1912")
    third.illustrations.create!(
      name: "Interior plate",
      page_number: "Facing page 10",
      image_url: "https://example.com/1912-interior.jpg"
    )
    fourth = novel.editions.create!(name: "1913 Edition", publication_date: "1913", cover_url: "https://example.com/1913-cover.jpg")
    fifth = novel.editions.create!(name: "1914 Edition", publication_date: "1914", cover_url: "https://example.com/1914-cover.jpg")
    sixth = novel.editions.create!(name: "1915 Edition", publication_date: "1915", cover_url: "https://example.com/1915-cover.jpg")
    seventh = novel.editions.create!(name: "1916 Edition", publication_date: "1916", cover_url: "https://example.com/1916-cover.jpg")

    entries = novel.cover_carousel_entries

    assert_equal [first.id, second.id, fourth.id, fifth.id, sixth.id], entries.map { |entry| entry[:edition].id }
    assert_equal "https://example.com/1911-dust-jacket.jpg", entries.second[:source]
    assert_equal second_dust_jacket.id, entries.second[:illustration].id
    assert_equal 5, entries.size
    assert_not_includes entries.map { |entry| entry[:edition].id }, third.id
    assert_not_includes entries.map { |entry| entry[:edition].id }, seventh.id
  end

  test "publication date parsing supports plain years, uncertain years, and circa years" do
    novel = Novel.create!(name: "Timeline Parsing Novel")
    plain_year = novel.editions.create!(name: "Plain year edition", publication_date: "1978")
    uncertain_year = novel.editions.create!(name: "Uncertain year edition", publication_date: "1889?")
    circa_year = novel.editions.create!(name: "Circa year edition", publication_date: "c. 1920")
    full_date = novel.editions.create!(name: "Full date edition", publication_date: "14 December 1919")
    undated = novel.editions.create!(name: "Undated edition", publication_date: "n. d.")

    assert_equal({ year: 1978 }, plain_year.send(:publication_date_parts))
    assert_equal({ year: 1889 }, uncertain_year.send(:publication_date_parts))
    assert_equal({ year: 1920 }, circa_year.send(:publication_date_parts))
    assert_equal({ year: 1919, mon: 12, mday: 14 }, full_date.send(:publication_date_parts))
    assert_equal({}, undated.send(:publication_date_parts))

    assert_equal 1978, plain_year.publication_year_value
    assert_equal 1920, circa_year.publication_year_value
    assert_equal [0, 1978, 0, 0, "1978", plain_year.id], plain_year.publication_sort_key
  end

  test "illustrator cover carousel entries prefer relevant cover art and cap at five" do
    illustrator = Illustrator.create!(name: "Carousel Illustrator")
    novel = Novel.create!(name: "Illustrator Cover Novel")
    editions = 7.times.map do |index|
      novel.editions.create!(
        name: "Edition #{index + 1}",
        publication_date: "19#{10 + index}",
        cover_url: "https://example.com/cover-#{index + 1}.jpg"
      )
    end

    matched_cover = editions[0].illustrations.create!(
      name: "Cover design",
      illustrator:,
      image_url: "https://example.com/interior-cover-reference.jpg"
    )
    dust_jacket = editions[1].illustrations.create!(
      name: "Edition two wrapper",
      illustrator:,
      page_number: "Dust Jacket",
      image_url: "https://example.com/dust-jacket-two.jpg"
    )
    editions[2].illustrations.create!(
      name: "Interior scene",
      illustrator:,
      page_number: "Facing page 22",
      image_url: "https://example.com/interior-scene.jpg"
    )
    editions[3].illustrations.create!(
      name: "Jacket art",
      illustrator:,
      image_url: "https://example.com/jacket-art-four.jpg"
    )
    editions[4].illustrations.create!(
      name: "Wrapper design",
      illustrator:,
      image_url: "https://example.com/wrapper-five.jpg"
    )
    editions[5].illustrations.create!(
      name: "Cover art",
      illustrator:,
      image_url: "https://example.com/cover-six.jpg"
    )
    editions[6].illustrations.create!(
      name: "Dust jacket design",
      illustrator:,
      page_number: "Dust Jacket",
      image_url: "https://example.com/dust-jacket-seven.jpg"
    )

    entries = illustrator.cover_carousel_entries

    assert_equal 5, entries.size
    assert_equal matched_cover.id, entries.first[:illustration].id
    assert_equal "https://example.com/cover-1.jpg", entries.first[:source]
    assert_equal dust_jacket.id, entries.second[:illustration].id
    assert_equal "https://example.com/cover-2.jpg", entries.second[:source]
    assert_not_includes entries.map { |entry| entry[:illustration].name }, "Interior scene"
    assert_not_includes entries.map { |entry| entry[:edition].id }, editions[6].id
  end

  test "illustrator cover carousel honors preferred edition ordering" do
    illustrator = Illustrator.create!(name: "Preferred Carousel Illustrator")
    novel_a = Novel.create!(name: "Preferred Novel A")
    novel_b = Novel.create!(name: "Preferred Novel B")
    novel_c = Novel.create!(name: "Preferred Novel C")
    edition_a = novel_a.editions.create!(name: "Authorized Edition", cover_url: "https://example.com/a-cover.jpg")
    edition_b = novel_b.editions.create!(name: "Authorized Edition", cover_url: "https://example.com/b-cover.jpg")
    edition_c = novel_c.editions.create!(name: "Authorized Edition", cover_url: "https://example.com/c-cover.jpg")

    edition_a.illustrations.create!(name: "A frontispiece", illustrator:, page_number: "Frontispiece", image_url: "https://example.com/a.jpg")
    edition_b.illustrations.create!(name: "B frontispiece", illustrator:, page_number: "Frontispiece", image_url: "https://example.com/b.jpg")
    edition_c.illustrations.create!(name: "C frontispiece", illustrator:, page_number: "Frontispiece", image_url: "https://example.com/c.jpg")

    original_method = Illustrator.method(:preferred_carousel_edition_ids)
    Illustrator.singleton_class.define_method(:preferred_carousel_edition_ids) { { illustrator.id => [edition_c.id, edition_a.id] } }

    begin
      entries = illustrator.cover_carousel_entries

      assert_equal [edition_c.id, edition_a.id, edition_b.id], entries.map { |entry| entry[:edition].id }
    ensure
      Illustrator.singleton_class.define_method(:preferred_carousel_edition_ids, original_method)
    end
  end
end
