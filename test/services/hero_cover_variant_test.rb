require "test_helper"

class HeroCoverVariantTest < ActiveSupport::TestCase
  setup do
    @novel = Novel.create!(name: "Hero Variant Novel")
    @edition = Edition.create!(novel: @novel, name: "Hero Variant Edition")
    FileUtils.rm_rf(HeroCoverVariant.root)
  end

  teardown do
    FileUtils.rm_rf(HeroCoverVariant.root)
  end

  test "url_for returns nil when no variant has been generated" do
    assert_nil HeroCoverVariant.url_for(@edition)
  end

  test "url_for returns the public path with a cache-busting timestamp when the variant exists" do
    FileUtils.mkdir_p(HeroCoverVariant.root)
    path = HeroCoverVariant.path_for(@edition)
    File.write(path, "jpeg-bytes")

    url = HeroCoverVariant.url_for(@edition)

    assert_equal "/hero-covers/#{@edition.id}.jpg?#{path.mtime.to_i}", url
  end

  test "generate! raises when the edition has no cover source" do
    assert_raises(ArgumentError) { HeroCoverVariant.generate!(@edition) }
  end
end
