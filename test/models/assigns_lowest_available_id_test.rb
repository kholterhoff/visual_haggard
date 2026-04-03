require "test_helper"

class AssignsLowestAvailableIdTest < ActiveSupport::TestCase
  test "novels fill the lowest available id gap" do
    Novel.create!(id: 1, name: "First Novel")
    Novel.create!(id: 3, name: "Third Novel")

    novel = Novel.create!(name: "Second Novel")

    assert_equal 2, novel.id
  end

  test "editions fill the lowest available id gap" do
    novel = Novel.create!(name: "Edition Parent Novel")
    Edition.create!(id: 1, novel:, name: "First Edition")
    Edition.create!(id: 3, novel:, name: "Third Edition")

    edition = Edition.create!(novel:, name: "Second Edition")

    assert_equal 2, edition.id
  end

  test "illustrators fill the lowest available id gap" do
    Illustrator.create!(id: 1, name: "First Illustrator")
    Illustrator.create!(id: 3, name: "Third Illustrator")

    illustrator = Illustrator.create!(name: "Second Illustrator")

    assert_equal 2, illustrator.id
  end

  test "illustrations fill the lowest available id gap" do
    novel = Novel.create!(name: "Illustration Parent Novel")
    edition = Edition.create!(novel:, name: "Illustration Parent Edition")
    Illustration.create!(id: 1, edition:, name: "First Illustration")
    Illustration.create!(id: 3, edition:, name: "Third Illustration")

    illustration = Illustration.create!(edition:, name: "Second Illustration")

    assert_equal 2, illustration.id
  end
end
