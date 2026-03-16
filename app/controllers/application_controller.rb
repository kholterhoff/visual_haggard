class ApplicationController < ActionController::Base
  before_action :set_permissions_policy_header

  private

  def set_permissions_policy_header
    response.set_header(
      "Permissions-Policy",
      "accelerometer=(), camera=(), geolocation=(), gyroscope=(), microphone=(), payment=(), usb=(), fullscreen=(self)"
    )
  end
end
