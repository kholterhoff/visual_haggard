require "test_helper"

class AdminArchiveEntryTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminUser.create!(
      email: "admin-#{SecureRandom.hex(6)}@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in @admin
  end

  test "admin can create an edition with an uploaded cover image" do
    novel = Novel.create!(name: "Admin Test Novel")
    uploaded_cover = uploaded_gif("cover")

    assert_difference("Edition.count", 1) do
      post "/admin/editions", params: {
        edition: {
          novel_id: novel.id,
          name: "Admin Test Edition",
          publisher: "Archive Press",
          publication_date: "1925",
          publication_city: "London",
          cover_image: uploaded_cover
        }
      }
    end

    edition = Edition.order(:id).last

    assert_response :redirect
    assert_equal novel, edition.novel
    assert_equal "Admin Test Edition", edition.name
    assert edition.cover_image.attached?
  end

  test "admin can create an illustration with an uploaded image and tags" do
    novel = Novel.create!(name: "Illustration Admin Novel")
    edition = Edition.create!(novel:, name: "Illustration Admin Edition")
    illustrator = Illustrator.create!(name: "Archive Artist")
    uploaded_image = uploaded_gif("illustration")

    assert_difference("Illustration.count", 1) do
      post "/admin/illustrations", params: {
        illustration: {
          edition_id: edition.id,
          illustrator_id: illustrator.id,
          name: "Frontispiece",
          page_number: "Frontispiece",
          description: "An uploaded test illustration.",
          tag_list: "elephant, woman",
          image: uploaded_image
        }
      }
    end

    illustration = Illustration.order(:id).last

    assert_response :redirect
    assert_equal edition, illustration.edition
    assert_equal illustrator, illustration.illustrator
    assert_equal ["elephant", "woman"], illustration.tag_list.sort
    assert illustration.image.attached?
  end

  test "admin illustration page shows other illustrations from the same novel" do
    novel = Novel.create!(name: "Grouped Illustration Novel")
    edition_a = Edition.create!(novel:, name: "First Edition", publication_date: "1910")
    edition_b = Edition.create!(novel:, name: "Second Edition", publication_date: "1915")
    current = edition_a.illustrations.create!(
      name: "Current plate",
      image_url: "https://example.com/current.jpg",
      identical_image_group: "plate-a"
    )
    grouped_match = edition_b.illustrations.create!(
      name: "Grouped match",
      image_url: "https://example.com/grouped.jpg",
      identical_image_group: "plate-a"
    )
    other_plate = edition_a.illustrations.create!(
      name: "Other plate",
      image_url: "https://example.com/other.jpg"
    )
    other_novel = Novel.create!(name: "Separate Novel")
    other_edition = Edition.create!(novel: other_novel, name: "Separate Edition")
    other_edition.illustrations.create!(
      name: "Outside plate",
      image_url: "https://example.com/outside.jpg",
      identical_image_group: "plate-a"
    )

    get "/admin/illustrations/#{current.id}"

    assert_response :success
    assert_includes response.body, "Other illustrations from Grouped Illustration Novel"
    assert_select ".admin-illustration-sibling-card", count: 2
    assert_select %(a[href="/admin/illustrations/#{grouped_match.id}"]), text: "Grouped match"
    assert_select %(a[href="/admin/illustrations/#{other_plate.id}"]), text: "Other plate"
    assert_select %(input[type="radio"][name="identical_grouping[#{grouped_match.id}]"][value="same"][checked="checked"]), count: 1
    assert_select %(input[type="radio"][name="identical_grouping[#{other_plate.id}]"][value="different"][checked="checked"]), count: 1
    assert_no_match(/Outside plate/, response.body)
  end

  test "admin can update identical illustration siblings from the thumbnail panel" do
    novel = Novel.create!(name: "Selection Novel")
    edition_a = Edition.create!(novel:, name: "First Edition")
    edition_b = Edition.create!(novel:, name: "Second Edition")
    current = edition_a.illustrations.create!(
      name: "Current plate",
      image_url: "https://example.com/current.jpg"
    )
    identical = edition_b.illustrations.create!(
      name: "Identical plate",
      image_url: "https://example.com/identical.jpg"
    )
    different = edition_b.illustrations.create!(
      name: "Different plate",
      image_url: "https://example.com/different.jpg"
    )

    patch "/admin/illustrations/#{current.id}/update_sibling_groupings", params: {
      identical_grouping: {
        identical.id.to_s => "same",
        different.id.to_s => "different"
      }
    }

    assert_response :redirect
    current.reload
    identical.reload
    different.reload

    assert current.identical_image_group.present?
    assert_equal current.identical_image_group, identical.identical_image_group
    assert_nil different.identical_image_group
  end

  private

  def uploaded_gif(prefix)
    fixture_file_upload("one_pixel.gif", "image/gif")
  end
end
