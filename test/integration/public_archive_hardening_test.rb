require "test_helper"

class PublicArchiveHardeningTest < ActionDispatch::IntegrationTest
  test "search renders pagefind shell and Rails fallback tag matches successfully" do
    novel = Novel.create!(name: "Searchable Novel", description: "A searchable archive novel")
    edition = novel.editions.create!(name: "Searchable Edition")
    illustrator = Illustrator.create!(name: "Searchable Illustrator")
    illustration = edition.illustrations.create!(
      name: "A tagged illustration",
      illustrator: illustrator,
      image_url: "https://example.com/illustration.jpg",
      tag_list: "woman"
    )

    get search_path, params: { search: "woman" }

    assert_response :success
    assert_select %(div.search-page[data-controller="pagefind-search"][data-pagefind-ignore="all"])
    assert_select %(div[data-pagefind-search-target="fallback"])
    assert_select %(div[data-pagefind-search-target="announcer"][aria-live="polite"])
    assert_includes response.body, illustration.name
    assert_select %(a[href="#search-illustrations"])
    assert_select %(a[href="#{illustration_path(illustration)}"])
  end

  test "public record pages expose pagefind metadata for static search" do
    novel = Novel.create!(name: "Pagefind Novel", description: "Novel description", tag_list: "elephant")
    edition = novel.editions.create!(
      name: "Pagefind Edition",
      publisher: "Longmans",
      publication_date: "1923",
      publication_city: "London",
      source: "Private Collection"
    )
    illustrator = Illustrator.create!(name: "Pagefind Illustrator", bio: "An illustrator biography")
    illustration = edition.illustrations.create!(
      name: "Pagefind Illustration",
      illustrator: illustrator,
      image_url: "https://example.com/illustration.jpg",
      description: "An elephant illustration",
      tag_list: "elephant"
    )

    get novel_path(novel)
    assert_response :success
    assert_select %(div.novel-page[data-pagefind-body])
    assert_select %(span[data-pagefind-filter="record_type"]), text: "novel"

    get edition_path(edition)
    assert_response :success
    assert_select %(div.edition-page[data-pagefind-body])
    assert_select %(span[data-pagefind-filter="record_type"]), text: "edition"

    get illustration_path(illustration)
    assert_response :success
    assert_select %(div.illustration-page[data-pagefind-body])
    assert_select %(span[data-pagefind-filter="record_type"]), text: "illustration"

    get illustrator_path(illustrator)
    assert_response :success
    assert_select %(div.illustrator-show-page[data-pagefind-body])
    assert_select %(span[data-pagefind-filter="record_type"]), text: "illustrator"
  end

  test "illustration record shows edition publication metadata" do
    novel = Novel.create!(name: "Maiwa's Revenge; Or, The War of the Little Hand")
    edition = novel.editions.create!(
      name: "New Edition",
      publisher: "Longmans, Green and Co.",
      publication_date: "1923",
      publication_city: "London",
      source: "Private Collection"
    )
    illustration = edition.illustrations.create!(
      name: "H. Rider Haggard",
      image_url: "https://example.com/portrait.jpg"
    )

    get illustration_path(illustration)

    assert_response :success
    assert_includes response.body, "Published by"
    assert_includes response.body, "Longmans, Green and Co."
    assert_includes response.body, "Published"
    assert_includes response.body, "1923"
    assert_includes response.body, "Publication City"
    assert_includes response.body, "London"
    assert_includes response.body, "Edition Source"
    assert_includes response.body, "Private Collection"
  end

  test "biography page links referenced novels into the archive" do
    Novel.create!(name: "Dawn")
    Novel.create!(name: "King Solomon's Mines")
    Novel.create!(name: "She, A History of Adventure")
    Novel.create!(name: "Allan Quatermain")
    maiwas_revenge = Novel.create!(name: "Maiwa's Revenge; Or, The War of the Little Hand")
    portrait_edition = maiwas_revenge.editions.create!(id: HomeController::BIOGRAPHY_PORTRAIT_EDITION_ID, name: "Biography Portrait Edition")
    portrait_edition.illustrations.create!(
      name: HomeController::BIOGRAPHY_PORTRAIT_NAME,
      image_url: "https://example.com/biography-portrait.jpg"
    )

    get biography_path

    internal_novel_link = lambda do |title|
      escaped_title = Regexp.escape(ERB::Util.html_escape(title))
      %r{<a[^>]+href="/novels/\d+"[^>]*>\s*<cite class="work-title">#{escaped_title}</cite>\s*</a>}m
    end

    assert_response :success
    assert_match internal_novel_link.call("Dawn"), response.body
    assert_equal 2, response.body.scan(internal_novel_link.call("King Solomon's Mines")).size
    assert_match internal_novel_link.call("She"), response.body
    assert_match internal_novel_link.call("Allan Quatermain"), response.body
    assert_match internal_novel_link.call("Maiwa's Revenge; Or, The War of the Little Hand"), response.body
    assert_select "a", text: "Treasure Island", count: 0
  end

  test "novel record shows a rotating cover and dust jacket carousel with pause control" do
    novel = Novel.create!(name: "Carousel Novel")
    first = novel.editions.create!(name: "1910 Edition", publication_date: "1910", cover_url: "https://example.com/1910-cover.jpg")
    second = novel.editions.create!(name: "1911 Edition", publication_date: "1911")
    second.illustrations.create!(
      name: "1911 Dust Jacket",
      page_number: "Dust Jacket",
      image_url: "https://example.com/1911-dust-jacket.jpg"
    )
    third = novel.editions.create!(name: "1912 Edition", publication_date: "1912")
    third.illustrations.create!(
      name: "Interior scene",
      page_number: "Facing page 12",
      image_url: "https://example.com/1912-interior.jpg"
    )

    get novel_path(novel)

    assert_response :success
    assert_select %(div.record-cover-carousel-rotator[aria-label="Cover and dust jacket carousel for Carousel Novel"])
    assert_select ".record-cover-slide", count: 2
    assert_select ".record-cover-slide-title", text: "1910 Edition"
    assert_select ".record-cover-slide-title", text: "1911 Edition"
    assert_select ".record-cover-slide-title", text: "1912 Edition", count: 0
    assert_select %(a.record-cover-slide-link[href="#{edition_path(first)}"]), count: 1
    assert_select %(a.record-cover-slide-link[href="#{edition_path(second)}"]), count: 1
    assert_select "button.record-cover-carousel-pause", text: "Pause motion"
    assert_select "button.record-cover-carousel-dot", count: 2
  end

  test "novel record hides generated further reading when description already includes that heading" do
    novel = Novel.create!(
      name: "Embedded Further Reading Novel",
      description: <<~HTML
        A novel description with its own bibliography.
        <h4>Further Reading</h4>
        <p>Embedded source entry.</p>
      HTML
    )
    novel.blog_posts.create!(
      title: "Template essay link",
      author: "Archive Editor",
      content: "A related essay that should not render as a duplicate section."
    )

    get novel_path(novel)

    assert_response :success
    assert_includes response.body, "Embedded source entry."
    assert_select %(a[href="#related-essays"]), count: 0
    assert_select "#related-essays", count: 0
    assert_select ".further-reading .page-eyebrow", text: "Further reading", count: 0
  end

  test "novel record shows generated further reading when description does not include that heading" do
    novel = Novel.create!(name: "Related Essay Novel", description: "A novel description without a bibliography heading.")
    novel.blog_posts.create!(
      title: "Template essay link",
      author: "Archive Editor",
      content: "A related essay that should render normally."
    )

    get novel_path(novel)

    assert_response :success
    assert_select %(a[href="#related-essays"]), text: "1 related essay"
    assert_select "#related-essays .page-eyebrow", text: "Further reading"
    assert_select "#related-essays a", text: "Template essay link"
  end

  test "novel description preserves embedded bibliography headings" do
    novel = Novel.create!(
      name: "Bibliography Heading Novel",
      description: <<~HTML
        Intro paragraph.

        <h4>Further Reading</h4>
        <p>Sample source entry.</p>
      HTML
    )

    get novel_path(novel)

    assert_response :success
    assert_select ".novel-description h4", text: "Further Reading"
    assert_select ".novel-description h4 + p", text: "Sample source entry."
    assert_no_match(/<p>Further Reading\s*<br/i, response.body)
  end

  test "illustrator record shows a rotating cover and dust jacket carousel with pause control" do
    illustrator = Illustrator.create!(name: "Carousel Illustrator")
    novel = Novel.create!(name: "Carousel Illustrator Novel")
    first = novel.editions.create!(name: "1910 Edition", publication_date: "1910", cover_url: "https://example.com/1910-cover.jpg")
    second = novel.editions.create!(name: "1911 Edition", publication_date: "1911", cover_url: "https://example.com/1911-cover.jpg")
    third = novel.editions.create!(name: "1912 Edition", publication_date: "1912")
    first.illustrations.create!(
      name: "Cover design",
      illustrator:,
      image_url: "https://example.com/cover-design.jpg"
    )
    second.illustrations.create!(
      name: "1911 Dust Jacket",
      illustrator:,
      page_number: "Dust Jacket",
      image_url: "https://example.com/1911-dust-jacket.jpg"
    )
    third.illustrations.create!(
      name: "Interior scene",
      illustrator:,
      page_number: "Facing page 18",
      image_url: "https://example.com/1912-interior.jpg"
    )

    get illustrator_path(illustrator)

    assert_response :success
    assert_select %(div.record-cover-carousel-rotator[aria-label="Cover and dust jacket carousel for Carousel Illustrator"])
    assert_select ".record-cover-slide", count: 2
    assert_select ".record-cover-slide-title", text: "1910 Edition"
    assert_select ".record-cover-slide-title", text: "1911 Edition"
    assert_select ".record-cover-slide-title", text: "Interior scene", count: 0
    assert_select %(a.record-cover-slide-link[href="#{edition_path(first)}"]), count: 1
    assert_select %(a.record-cover-slide-link[href="#{edition_path(second)}"]), count: 1
    assert_select "button.record-cover-carousel-pause", text: "Pause motion"
    assert_select "button.record-cover-carousel-dot", count: 2
  end

  test "illustration page lists other variant images when grouped" do
    novel = Novel.create!(name: "Grouped Illustration Novel")
    edition_a = novel.editions.create!(name: "1910 edition", publication_date: "1910")
    edition_b = novel.editions.create!(name: "1915 edition", publication_date: "1915")
    current = edition_a.illustrations.create!(
      name: "Current plate",
      image_url: "https://example.com/current.jpg",
      identical_image_group: "plate-a"
    )
    identical = edition_b.illustrations.create!(
      name: "Second plate",
      image_url: "https://example.com/second.jpg",
      page_number: "Frontispiece",
      identical_image_group: "plate-a"
    )
    edition_a.illustrations.create!(
      name: "Ungrouped plate",
      image_url: "https://example.com/ungrouped.jpg"
    )

    get illustration_path(current)

    assert_response :success
    assert_select "section.illustration-identical-images", count: 1
    assert_select "section.illustration-identical-images h2", text: "Other variants in the archive"
    assert_select "section.illustration-identical-images button.illustration-compare-trigger", text: "Compare Variant Images"
    assert_select %(section.illustration-identical-images a.illustration-card--linked[href="#{illustration_path(identical)}"]), count: 1
    assert_select "section.illustration-identical-images .illustration-card-title-link", text: "Second plate"
    assert_select "section.illustration-identical-images .illustration-card-meta", text: "1915 edition"
    assert_select "section.illustration-identical-images .illustration-card", count: 1
    assert_select "section.illustration-identical-images dialog.illustration-compare-dialog", count: 1
    assert_select %(section.illustration-identical-images dialog a.illustration-compare-card-title[href="#{illustration_path(current)}"]), text: "Current plate"
    assert_select %(section.illustration-identical-images dialog a.illustration-compare-card-title[href="#{illustration_path(identical)}"]), text: "Second plate"
  end

  test "illustration page lists other illustrations of this scene" do
    novel = Novel.create!(name: "Text Moment Novel")
    edition_a = novel.editions.create!(name: "1910 edition", publication_date: "1910")
    edition_b = novel.editions.create!(name: "1915 edition", publication_date: "1915")
    current = edition_a.illustrations.create!(
      name: "Current plate",
      image_url: "https://example.com/current.jpg",
      identical_image_group: "plate-a",
      text_moment_group: "moment-a"
    )
    variant = edition_b.illustrations.create!(
      name: "Variant plate",
      image_url: "https://example.com/variant.jpg",
      identical_image_group: "plate-a"
    )
    same_moment = edition_b.illustrations.create!(
      name: "Same scene plate",
      image_url: "https://example.com/moment.jpg",
      page_number: "Facing page 12",
      text_moment_group: "moment-a"
    )

    get illustration_path(current)

    assert_response :success
    assert_select "section.illustration-identical-images", count: 1
    assert_select "section.illustration-text-moment-group", count: 1
    assert_select "section.illustration-text-moment-group h2", text: "Other illustrations of this scene"
    assert_select "section.illustration-text-moment-group button.illustration-compare-trigger", text: "Compare Illustrations"
    assert_select %(section.illustration-text-moment-group a.illustration-card--linked[href="#{illustration_path(same_moment)}"]), count: 1
    assert_select "section.illustration-text-moment-group .illustration-card-title-link", text: "Same scene plate"
    assert_select "section.illustration-text-moment-group .illustration-card-title-link", text: "Variant plate", count: 0
    assert_operator response.body.index("Other variants in the archive"), :<, response.body.index("Other illustrations of this scene")
    assert_select "section.illustration-text-moment-group dialog.illustration-compare-dialog h2", text: "Compare Illustrations of This Scene"
    assert_select %(section.illustration-text-moment-group dialog a.illustration-compare-card-title[href="#{illustration_path(current)}"]), text: "Current plate"
    assert_select %(section.illustration-text-moment-group dialog a.illustration-compare-card-title[href="#{illustration_path(same_moment)}"]), text: "Same scene plate"
    assert_select %(section.illustration-text-moment-group dialog a.illustration-compare-card-title[href="#{illustration_path(variant)}"]), count: 0
  end

  test "illustration cards appear only in variants when an illustration is both a variant and the same scene" do
    novel = Novel.create!(name: "Overlapping Group Novel")
    edition_a = novel.editions.create!(name: "1910 edition", publication_date: "1910")
    edition_b = novel.editions.create!(name: "1915 edition", publication_date: "1915")
    current = edition_a.illustrations.create!(
      name: "Current plate",
      image_url: "https://example.com/current.jpg",
      identical_image_group: "plate-a",
      text_moment_group: "moment-a"
    )
    overlapping = edition_b.illustrations.create!(
      name: "Overlapping plate",
      image_url: "https://example.com/overlap.jpg",
      identical_image_group: "plate-a",
      text_moment_group: "moment-a"
    )

    get illustration_path(current)

    assert_response :success
    assert_select %(section.illustration-identical-images a.illustration-card--linked[href="#{illustration_path(overlapping)}"]), count: 1
    assert_select %(section.illustration-text-moment-group a.illustration-card--linked[href="#{illustration_path(overlapping)}"]), count: 0
    assert_select "section.illustration-text-moment-group", count: 0
  end

  test "illustration page hides grouping sections when no group is assigned" do
    novel = Novel.create!(name: "Ungrouped Novel")
    edition = novel.editions.create!(name: "Ungrouped Edition")
    illustration = edition.illustrations.create!(
      name: "Solo plate",
      image_url: "https://example.com/solo.jpg"
    )

    get illustration_path(illustration)

    assert_response :success
    assert_select "section.illustration-identical-images", count: 0
    assert_select "section.illustration-text-moment-group", count: 0
  end

  test "illustration page still renders when grouping columns are unavailable" do
    novel = Novel.create!(name: "Migration Safety Novel")
    edition = novel.editions.create!(name: "Migration Safety Edition")
    illustration = edition.illustrations.create!(
      name: "Migration Safety Illustration",
      image_url: "https://example.com/safe.jpg"
    )

    original_identical_method = Illustration.method(:identical_image_group_supported?)
    original_text_moment_method = Illustration.method(:text_moment_group_supported?)
    Illustration.singleton_class.define_method(:identical_image_group_supported?) { false }
    Illustration.singleton_class.define_method(:text_moment_group_supported?) { false }

    begin
      get illustration_path(illustration)
    ensure
      Illustration.singleton_class.define_method(:identical_image_group_supported?, original_identical_method)
      Illustration.singleton_class.define_method(:text_moment_group_supported?, original_text_moment_method)
    end

    assert_response :success
    assert_select "section.illustration-identical-images", count: 0
    assert_select "section.illustration-text-moment-group", count: 0
  end

  test "edition record shows explicit publication metadata" do
    novel = Novel.create!(name: "Maiwa's Revenge; Or, The War of the Little Hand")
    edition = novel.editions.create!(
      name: "New Edition",
      publisher: "Longmans, Green and Co.",
      publication_date: "1923",
      publication_city: "London",
      source: "Private Collection"
    )

    get edition_path(edition)

    assert_response :success
    assert_includes response.body, "Edition"
    assert_includes response.body, "New Edition"
    assert_includes response.body, "Novel"
    assert_includes response.body, "Maiwa&#39;s Revenge; Or, The War of the Little Hand"
    assert_includes response.body, "Published by"
    assert_includes response.body, "Longmans, Green and Co."
    assert_includes response.body, "Published"
    assert_includes response.body, "1923"
    assert_includes response.body, "Publication City"
    assert_includes response.body, "London"
    assert_includes response.body, "Edition Source"
    assert_includes response.body, "Private Collection"
  end

  test "public user auth routes are disabled" do
    get "/users/sign_up"

    assert_response :not_found
  end

  test "security headers are present on public responses" do
    get root_path

    assert_response :success
    assert_match(/default-src 'self' https:/, response.headers["Content-Security-Policy"])
    assert_equal(
      "accelerometer=(), camera=(), geolocation=(), gyroscope=(), microphone=(), payment=(), usb=(), fullscreen=(self)",
      response.headers["Permissions-Policy"]
    )
  end

  test "public pages expose skip link, primary navigation, and labeled search" do
    13.times do |record_index|
      Novel.create!(name: "Paginated Novel #{record_index}")
    end

    get novels_path

    assert_response :success
    assert_select %(a.skip-link[href="#main-content"]), text: "Skip to main content"
    assert_select %(main#main-content[tabindex="-1"])
    assert_select %(nav.site-nav[aria-label="Primary"])
    assert_select %(label.sr-only[for="search"]), text: "Search the archive"
    assert_select %(nav.site-nav a[aria-current="page"]), text: "Novels"
    assert_select %(nav.pagination[aria-label="Pagination"])
  end

  test "novel record exposes illustrator chip and illustrator archive section" do
    novel = Novel.create!(name: "Illustrated Novel")
    edition = novel.editions.create!(name: "First Issue", publication_date: "January 1913")
    illustrator_a = Illustrator.create!(name: "Ada Artist")
    illustrator_b = Illustrator.create!(name: "Beatrice Brush")
    edition.illustrations.create!(name: "Plate one", illustrator: illustrator_a, image_url: "https://example.com/plate-one.jpg")
    edition.illustrations.create!(name: "Plate two", illustrator: illustrator_a, image_url: "https://example.com/plate-two.jpg")
    edition.illustrations.create!(name: "Plate three", illustrator: illustrator_b, image_url: "https://example.com/plate-three.jpg")

    get novel_path(novel)

    assert_response :success
    assert_select %(a[href="#edition-archive"]), text: "1 edition"
    assert_select %(a[href="#illustrator-archive"]), text: "2 illustrators"
    assert_select %(a[href="#illustration-archive"]), text: "3 illustrations"
    assert_select %(section#illustrator-archive h2), text: "Illustrators of Illustrated Novel"
    assert_select %(section#illustrator-archive a[href="#{illustrator_path(illustrator_a)}"])
    assert_select %(section#illustrator-archive a[href="#{illustrator_path(illustrator_b)}"])
  end

  test "illustrator record groups illustrations by novel and exposes jump chips" do
    illustrator = Illustrator.create!(name: "Grouped Illustrator")
    novel_a = Novel.create!(name: "Alpha Novel")
    novel_b = Novel.create!(name: "Beta Novel")
    edition_a = novel_a.editions.create!(name: "First Alpha Edition", publication_date: "February 1913")
    edition_b = novel_a.editions.create!(name: "Second Alpha Edition", publication_date: "January 1913")
    edition_c = novel_b.editions.create!(name: "Beta Edition", publication_date: "1912")
    alpha_first = edition_a.illustrations.create!(name: "Alpha later", illustrator:, image_url: "https://example.com/alpha-later.jpg")
    alpha_second = edition_b.illustrations.create!(name: "Alpha earlier", illustrator:, image_url: "https://example.com/alpha-earlier.jpg")
    beta = edition_c.illustrations.create!(name: "Beta plate", illustrator:, image_url: "https://example.com/beta.jpg")

    get illustrator_path(illustrator)

    assert_response :success
    assert_select "h1.page-title", text: "Grouped Illustrator"
    assert_select %(section#illustrator-work-archive > .section-heading .page-eyebrow), count: 0
    assert_select %(section#illustrator-work-archive > .section-heading h2), text: "3 Illustrations by Grouped Illustrator"
    assert_select %(section#illustrator-work-archive .illustrator-work-jumps a[href="#illustrator-work-novel-#{novel_a.id}"] cite.work-title), text: "Alpha Novel"
    assert_select %(section#illustrator-work-archive .illustrator-work-jumps a[href="#illustrator-work-novel-#{novel_b.id}"] cite.work-title), text: "Beta Novel"
    assert_select %(section#illustrator-work-novel-#{novel_a.id} h3 cite.work-title), text: "Alpha Novel"
    assert_select %(section#illustrator-work-novel-#{novel_b.id} h3 cite.work-title), text: "Beta Novel"
    assert_select %(section#illustrator-work-novel-#{novel_a.id} a.illustrator-work-link[href="#{illustration_path(alpha_first)}"]), count: 1
    assert_select %(section#illustrator-work-novel-#{novel_a.id} a.illustrator-work-link[href="#{illustration_path(alpha_second)}"]), count: 1
    assert_select %(section#illustrator-work-novel-#{novel_b.id} a.illustrator-work-link[href="#{illustration_path(beta)}"]), count: 1
    assert_operator response.body.index(alpha_second.name).to_i, :<, response.body.index(alpha_first.name).to_i
    assert_includes response.body, beta.name
  end

  test "illustrator meta chips use short novel titles while group headings keep long titles" do
    illustrator = Illustrator.create!(name: "Short Title Illustrator")
    novel = Novel.create!(name: "Maiwa's Revenge; Or, The War of the Little Hand")
    edition = novel.editions.create!(name: "Short Title Edition", publication_date: "1923")
    edition.illustrations.create!(
      name: "Short title plate",
      illustrator: illustrator,
      image_url: "https://example.com/short-title.jpg"
    )

    get illustrator_path(illustrator)

    assert_response :success
    assert_select %(section#illustrator-work-archive .illustrator-work-jumps a[href="#illustrator-work-novel-#{novel.id}"] cite.work-title), text: "Maiwa's Revenge"
    assert_select %(section#illustrator-work-novel-#{novel.id} h3 cite.work-title), text: "Maiwa's Revenge; Or, The War of the Little Hand"
  end

  test "illustrator bios restore legacy italic markup in citations" do
    illustrator = Illustrator.create!(
      name: "Citation Illustrator",
      bio: %(Houfe, Simon. &lt;span style="font-style:italic;"&gt;The Dictionary of British Book Illustrators and Caricaturists 1800-1914&lt;/span&gt;. Woodbridge, Suffolk: Antique Collectors' Club, 1981.)
    )

    get illustrator_path(illustrator)

    assert_response :success
    assert_select ".illustrator-bio em", text: "The Dictionary of British Book Illustrators and Caricaturists 1800-1914"
    assert_no_match(/&lt;span/, response.body)
  end

  test "illustrator bios preserve embedded further reading headings" do
    illustrator = Illustrator.create!(
      name: "Bibliography Illustrator",
      bio: <<~HTML
        Biographical note.

        <h4>Further Reading</h4>
        <p>Sample bibliography entry.</p>
      HTML
    )

    get illustrator_path(illustrator)

    assert_response :success
    assert_select ".illustrator-bio > p", text: "Biographical note."
    assert_select ".illustrator-bio h4", text: "Further Reading"
    assert_select ".illustrator-bio h4 + p", text: "Sample bibliography entry."
  end

  test "long illustration archives render a back to top control" do
    novel = Novel.create!(name: "Long Archive Novel")
    edition = novel.editions.create!(name: "Long Archive Edition")

    13.times do |index|
      edition.illustrations.create!(
        name: "Long Archive Illustration #{index}",
        image_url: "https://example.com/long-archive-#{index}.jpg"
      )
    end

    get novel_path(novel)

    assert_response :success
    assert_select %(div.novel-page[data-controller="back-to-top"])
    assert_select %(button.back-to-top-button[data-back-to-top-target="button"][hidden]), text: "Back to top"
    assert_select %([data-back-to-top-target="item"]), count: 13
  end

  test "illustration and edition records retain semantic headings for assistive technology" do
    novel = Novel.create!(name: "Heading Test Novel")
    edition = novel.editions.create!(name: "Heading Test Edition")
    illustration = edition.illustrations.create!(
      name: "Heading Test Illustration",
      image_url: "https://example.com/illustration.jpg"
    )

    get edition_path(edition)
    assert_response :success
    assert_select "h1.sr-only", text: "Heading Test Edition"

    get illustration_path(illustration)
    assert_response :success
    assert_select "h1.sr-only", text: "Heading Test Illustration"
  end

  test "public views italicize work titles" do
    novel = Novel.create!(name: "Italicized Novel")
    edition = novel.editions.create!(name: "Italicized Edition")
    illustration = edition.illustrations.create!(name: "Italicized Illustration", image_url: "https://example.com/illustration.jpg")

    get novel_path(novel)
    assert_response :success
    assert_select "h1 cite.work-title", text: "Italicized Novel"

    get edition_path(edition)
    assert_response :success
    assert_select ".record-breadcrumbs cite.work-title", text: "Italicized Novel"

    get illustration_path(illustration)
    assert_response :success
    assert_select ".record-meta dd cite.work-title", text: "Italicized Novel"

    get search_path, params: { search: "Italicized" }
    assert_response :success
    assert_select "#search-novels h3 cite.work-title", text: "Italicized Novel"
  end
end
