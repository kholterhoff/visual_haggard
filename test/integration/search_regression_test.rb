require "test_helper"

class SearchRegressionTest < ActionDispatch::IntegrationTest
  test "search smoke test returns illustration novel and illustrator results" do
    novel = Novel.create!(name: "Search Guard Novel", description: "A search regression novel about a shipwreck.")
    edition = novel.editions.create!(name: "Search Guard Edition", publisher: "Archive Press")
    illustrator = Illustrator.create!(name: "Search Guard Illustrator", bio: "Known for shipwreck illustration.")
    illustration = edition.illustrations.create!(
      name: "Shipwreck plate",
      illustrator: illustrator,
      image_url: "https://example.com/shipwreck-plate.jpg",
      description: "A shipwreck crashes against the rocks."
    )

    get search_path, params: { search: "shipwreck" }

    assert_response :success
    assert_select %(div.search-page[data-controller="pagefind-search"][data-pagefind-ignore="all"])
    assert_select %(div[data-pagefind-search-target="fallback"][data-fallback-query-rendered="true"])
    assert_select %(#search-illustrations a.search-card.search-card--illustration[href="#{illustration_path(illustration)}"])
    assert_select %(#search-novels a.search-card[href="#{novel_path(novel)}"])
    assert_select %(#search-illustrators a.search-card.search-card--illustrator[href="#{illustrator_path(illustrator)}"])
    assert_select ".search-hero-panel h2", text: "shipwreck"
  end

  test "search fallback preserves inline work-title formatting in excerpts" do
    novel = Novel.create!(
      name: "Search Formatting Novel",
      description: <<~HTML
        <cite class="work-title">Search Formatting Novel</cite> belongs beside <cite class="work-title">She</cite> in the archive.
      HTML
    )
    novel.editions.create!(name: "Search Formatting Edition")

    get search_path, params: { search: "belongs" }

    assert_response :success
    assert_select %(#search-novels a.search-card[href="#{novel_path(novel)}"] .search-card-excerpt cite.work-title), text: "Search Formatting Novel"
    assert_select %(#search-novels a.search-card[href="#{novel_path(novel)}"] .search-card-excerpt cite.work-title), text: "She"
  end
end
