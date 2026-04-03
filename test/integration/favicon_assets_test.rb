require "test_helper"

class FaviconAssetsTest < ActionDispatch::IntegrationTest
  test "public layout links favicon assets" do
    get "/"

    assert_response :success
    assert_select %(link[rel="icon"][href="/favicon.svg?v=20260402c"][type="image/svg+xml"]), count: 1
    assert_select %(link[rel="icon"][href="/favicon-32.png?v=20260402c"][type="image/png"][sizes="32x32"]), count: 1
    assert_select %(link[rel="alternate icon"][href="/favicon.ico?v=20260402c"][type="image/x-icon"]), count: 1
    assert_select %(link[rel="apple-touch-icon"][href="/apple-touch-icon.png?v=20260402c"][sizes="180x180"]), count: 1

    assert_operator Rails.root.join("public/favicon.svg").size, :>, 0
    assert_operator Rails.root.join("public/favicon-32.png").size, :>, 0
    assert_operator Rails.root.join("public/favicon.ico").size, :>, 0
    assert_operator Rails.root.join("public/apple-touch-icon.png").size, :>, 0
    assert_operator Rails.root.join("public/apple-touch-icon-precomposed.png").size, :>, 0
  end

  test "admin login page loads with the public favicon" do
    get "/admin/login"

    assert_response :success
    assert_select %(link[rel="icon"][href="/favicon.ico?v=20260402c"][type="image/x-icon"]), count: 1
  end
end
