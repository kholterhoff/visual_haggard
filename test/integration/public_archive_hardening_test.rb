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
    get novels_path

    assert_response :success
    assert_select %(a.skip-link[href="#main-content"]), text: "Skip to main content"
    assert_select %(main#main-content[tabindex="-1"])
    assert_select %(nav.site-nav[aria-label="Primary"])
    assert_select %(label.sr-only[for="search"]), text: "Search the archive"
    assert_select %(nav.site-nav a[aria-current="page"]), text: "Novels"
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
end
