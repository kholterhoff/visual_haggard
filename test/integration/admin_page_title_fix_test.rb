require "test_helper"

class AdminPageTitleFixTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminUser.create!(
      email: "admin-#{SecureRandom.hex(6)}@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in @admin
  end

  test "admin illustration show title renders apostrophes in the browser tab" do
    novel = Novel.create!(name: "Admin Title Novel")
    edition = Edition.create!(novel:, name: "Admin Title Edition")
    illustration = edition.illustrations.create!(
      name: "'You remember my words when you lie a-dying'",
      image_url: "https://example.com/plate.jpg"
    )

    get "/admin/illustrations/#{illustration.id}"

    assert_response :success
    assert_select "title", text: "'You remember my words when you lie a-dying' | Visual Haggard"
    assert_no_match("&amp;#39;", response.body)
  end
end
