class OriginalIllustration < ApplicationRecord
  STRING_MAXIMUM = 255

  belongs_to :novel
  belongs_to :illustrator
  has_many :illustrations, dependent: :nullify

  # Admin file uploads are pushed straight to the legacy S3 bucket rather than
  # Active Storage so the resulting URLs survive static publishes. Unlike
  # illustrations and editions there are no legacy Paperclip columns here, so
  # the uploaded file's public URL is stored in image_url.
  attr_accessor :image_upload

  after_save :store_image_upload_in_legacy_s3

  validates :novel, :illustrator, presence: true
  validates :title, :dimensions, :medium, :source, :year, :image_url,
            length: { maximum: STRING_MAXIMUM }, allow_blank: true
  validate :validate_image_upload

  def display_title
    title.presence || "Untitled original artwork"
  end

  def display_image_source
    image_url.presence
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at dimensions id illustrator_id image_url medium novel_id source title updated_at year]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[novel illustrator illustrations]
  end

  private

  def validate_image_upload
    return if image_upload.blank?

    unless image_upload.respond_to?(:original_filename) && image_upload.respond_to?(:read)
      errors.add(:image_upload, "must be an uploaded file")
      return
    end

    unless image_upload.content_type.to_s.start_with?("image/")
      errors.add(:image_upload, "must be an image file")
    end

    unless LegacyS3ImageUploader.configured?
      errors.add(:image_upload, "cannot be stored because AWS S3 credentials are missing. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (or add them to Rails credentials under aws:).")
    end
  end

  def store_image_upload_in_legacy_s3
    file = image_upload
    return if file.blank?

    filename = sanitized_upload_filename(file)
    key = "original_illustrations/images/000/000/#{id}/original/#{filename}"
    file.rewind
    LegacyS3ImageUploader.upload(
      key: key,
      io: file,
      content_type: file.content_type
    )

    timestamp = Time.current
    update_columns(
      image_url: "#{LegacyS3ImageUploader.public_url(key)}?#{timestamp.to_i}",
      updated_at: timestamp
    )
    self.image_upload = nil
  end

  def sanitized_upload_filename(file)
    basename = File.basename(file.original_filename.to_s).gsub(/[^a-zA-Z0-9_.\-]/, "_")
    basename.match?(/[a-zA-Z0-9]/) ? basename : "original-illustration-#{id}"
  end
end
