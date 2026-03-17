require "uri"

module SafeUrlFields
  extend ActiveSupport::Concern

  LEGACY_REFERENCE_PATTERN = %r{\A/?[A-Za-z0-9_./\-]+\z}.freeze

  class_methods do
    def validates_http_url(*attributes, allow_blank: true)
      attributes.each do |attribute|
        validate do
          validate_http_url_field(attribute, allow_blank:)
        end
      end
    end

    def validates_http_url_or_legacy_reference(*attributes, allow_blank: true)
      attributes.each do |attribute|
        validate do
          validate_http_url_or_legacy_reference_field(attribute, allow_blank:)
        end
      end
    end
  end

  private

  def validate_http_url_field(attribute, allow_blank: true)
    value = read_attribute(attribute).to_s.strip
    return if value.blank? && allow_blank
    return if absolute_http_url?(value)

    errors.add(attribute, "must be a valid http:// or https:// URL")
  end

  def validate_http_url_or_legacy_reference_field(attribute, allow_blank: true)
    value = read_attribute(attribute).to_s.strip
    return if value.blank? && allow_blank
    return if absolute_http_url?(value)
    return if legacy_reference?(value)

    errors.add(attribute, "must be a valid http:// or https:// URL or legacy file reference")
  end

  def absolute_http_url?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError, ArgumentError
    false
  end

  def legacy_reference?(value)
    value.match?(LEGACY_REFERENCE_PATTERN)
  end
end
