require "test_helper"
require "tmpdir"

class StaticSiteExporterTest < ActiveSupport::TestCase
  test "defaults to npx pagefind when npx is available" do
    npx_directory = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).find do |directory|
      File.executable?(File.join(directory, "npx"))
    end

    skip "npx is not available on PATH in this environment" unless npx_directory

    with_modified_path(npx_directory) do
      exporter = StaticSiteExporter.new(
        output_root: Pathname("/tmp/visual_haggard_dist"),
        precompile_assets: false,
        copy_public_assets: false
      )

      assert_equal "npx --yes pagefind", exporter.instance_variable_get(:@pagefind_command)
    end
  end

  test "falls back to the pagefind binary when npx is unavailable" do
    with_modified_path("/definitely/missing") do
      exporter = StaticSiteExporter.new(
        output_root: Pathname("/tmp/visual_haggard_dist"),
        precompile_assets: false,
        copy_public_assets: false
      )

      assert_equal "pagefind", exporter.instance_variable_get(:@pagefind_command)
    end
  end

  test "maps root and paginated novel paths to static files" do
    exporter = StaticSiteExporter.new(
      output_root: Pathname("/tmp/visual_haggard_dist"),
      precompile_assets: false,
      copy_public_assets: false,
      run_pagefind: false
    )

    assert_equal Pathname("/tmp/visual_haggard_dist/index.html"), exporter.output_path_for("/")
    assert_equal Pathname("/tmp/visual_haggard_dist/novels/index.html"), exporter.output_path_for("/novels")
    assert_equal Pathname("/tmp/visual_haggard_dist/novels/page/3/index.html"), exporter.output_path_for("/novels?page=3")
    assert_equal Pathname("/tmp/visual_haggard_dist/illustrations/962/index.html"), exporter.output_path_for("/illustrations/962")
  end

  test "rewrites novel pagination query links to static paths" do
    exporter = StaticSiteExporter.new(
      output_root: Pathname("/tmp/visual_haggard_dist"),
      precompile_assets: false,
      copy_public_assets: false,
      run_pagefind: false
    )
    html = <<~HTML
      <html>
        <body>
          <a href="/novels?page=2">2</a>
          <a href="/novels?page=1#novel-archive-browse">1</a>
        </body>
      </html>
    HTML

    rewritten = exporter.rewrite_html_for_static(html)

    assert_includes rewritten, %(href="/novels/page/2/")
    assert_includes rewritten, %(href="/novels#novel-archive-browse")
  end

  test "writes github pages support files when exporting" do
    novel = Novel.create!(name: "Pages Export Novel")
    novel.editions.create!(name: "Pages Export Edition")

    Dir.mktmpdir do |dir|
      exporter = StaticSiteExporter.new(
        output_root: Pathname(dir),
        precompile_assets: false,
        copy_public_assets: false,
        run_pagefind: false,
        custom_domain: "www.visualhaggard.org"
      )

      exporter.export!

      assert_equal "", Pathname(dir).join(".nojekyll").read
      assert_equal "www.visualhaggard.org\n", Pathname(dir).join("CNAME").read
    end
  end

  test "exports public pages into dist" do
    novel = Novel.create!(name: "Static Export Novel")
    edition = novel.editions.create!(name: "Static Export Edition")
    illustration = edition.illustrations.create!(
      name: "Static Export Illustration",
      image_url: "https://example.com/static-export.jpg"
    )
    illustrator = Illustrator.create!(name: "Static Export Illustrator")
    illustration.update!(illustrator: illustrator)

    Dir.mktmpdir do |dir|
      exporter = StaticSiteExporter.new(
        output_root: Pathname(dir),
        precompile_assets: false,
        copy_public_assets: false,
        run_pagefind: false
      )

      exporter.export!

      assert_path_exists Pathname(dir).join("index.html")
      assert_path_exists Pathname(dir).join("novels", "index.html")
      assert_path_exists Pathname(dir).join("novels", novel.id.to_s, "index.html")
      assert_path_exists Pathname(dir).join("editions", edition.id.to_s, "index.html")
      assert_path_exists Pathname(dir).join("illustrations", illustration.id.to_s, "index.html")
      assert_path_exists Pathname(dir).join("illustrators", illustrator.id.to_s, "index.html")
      assert_path_exists Pathname(dir).join("search", "index.html")
      assert_path_exists Pathname(dir).join("static_export_report.txt")
    end
  end

  private

  def assert_path_exists(pathname)
    assert pathname.exist?, "Expected #{pathname} to exist"
  end

  def with_modified_path(path)
    original_path = ENV["PATH"]
    ENV["PATH"] = path
    yield
  ensure
    ENV["PATH"] = original_path
  end
end
