require "aws-sdk-s3"

# Uploads admin-supplied images straight to the legacy public S3 bucket using
# the same key layout the original Paperclip attachments used, so uploaded
# images resolve through the existing legacy URL builders (see
# Illustration#paperclip_image_url) and remain durable for static publishes.
class LegacyS3ImageUploader
  class NotConfiguredError < StandardError; end

  DEFAULT_BUCKET = "haggard".freeze
  DEFAULT_REGION = "us-west-2".freeze
  CACHE_CONTROL = "public, max-age=31536000".freeze

  class << self
    def bucket
      ENV["ILLUSTRATIONS_S3_BUCKET"].presence || DEFAULT_BUCKET
    end

    def region
      ENV["ILLUSTRATIONS_S3_REGION"].presence || DEFAULT_REGION
    end

    def access_key_id
      ENV["AWS_ACCESS_KEY_ID"].presence || Rails.application.credentials.dig(:aws, :access_key_id)
    end

    def secret_access_key
      ENV["AWS_SECRET_ACCESS_KEY"].presence || Rails.application.credentials.dig(:aws, :secret_access_key)
    end

    def configured?
      access_key_id.present? && secret_access_key.present?
    end

    # Path-style URL matching how the legacy bucket's objects are referenced
    # throughout the archive (see DbImageUrlResolver::LEGACY_S3_ROOT).
    def public_url(key)
      "https://s3-#{region}.amazonaws.com/#{bucket}/#{key}"
    end

    def upload(key:, io:, content_type:)
      raise NotConfiguredError, "AWS S3 credentials are not configured" unless configured?

      client.put_object(
        bucket: bucket,
        key: key,
        body: io,
        content_type: content_type,
        acl: "public-read",
        cache_control: CACHE_CONTROL
      )
    rescue Aws::S3::Errors::AccessControlListNotSupported
      # Buckets with "bucket owner enforced" object ownership reject per-object
      # ACLs and rely on a bucket policy for public reads instead.
      io.rewind
      client.put_object(
        bucket: bucket,
        key: key,
        body: io,
        content_type: content_type,
        cache_control: CACHE_CONTROL
      )
    end

    private

    def client
      Aws::S3::Client.new(
        region: region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key
      )
    end
  end
end
