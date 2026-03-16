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

  private

  def uploaded_gif(prefix)
    fixture_file_upload("one_pixel.gif", "image/gif")
  end
end
