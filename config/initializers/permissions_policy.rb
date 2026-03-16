Rails.application.config.permissions_policy do |policy|
  policy.accelerometer :none
  policy.camera :none
  policy.geolocation :none
  policy.gyroscope :none
  policy.microphone :none
  policy.payment :none
  policy.usb :none
  policy.fullscreen :self
end
