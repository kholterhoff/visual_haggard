require "test_helper"
require "minitest/mock"

class IllustrationImageUploadTest < ActiveSupport::TestCase
  setup do
    novel = Novel.create!(name: "Upload Novel")
    @edition = Edition.create!(novel: novel, name: "Upload Edition")
  end

  test "saving with an image upload stores it in the legacy S3 bucket and fills legacy columns" do
    uploaded_calls = []
    upload_stub = lambda do |key:, io:, content_type:|
      uploaded_calls << { key: key, bytes: io.read, content_type: content_type }
    end

    illustration = nil
    LegacyS3ImageUploader.stub :configured?, true do
      LegacyS3ImageUploader.stub :upload, upload_stub do
        illustration = Illustration.create!(
          edition: @edition,
          name: "Uploaded illustration",
          image_upload: uploaded_file("he Knelt(164).jpg", "image/jpeg", "jpeg-bytes")
        )
      end
    end

    illustration.reload
    assert_equal 1, uploaded_calls.length
    upload = uploaded_calls.first
    assert_equal "illustrations/images/000/000/#{illustration.id}/original/he_Knelt_164_.jpg", upload[:key]
    assert_equal "jpeg-bytes", upload[:bytes]
    assert_equal "image/jpeg", upload[:content_type]

    assert_equal "he_Knelt_164_.jpg", illustration.image_file_name
    assert_equal "image/jpeg", illustration.image_content_type
    assert_equal "jpeg-bytes".bytesize, illustration.image_file_size
    assert_predicate illustration.image_updated_at, :present?

    expected_url = "https://s3-us-west-2.amazonaws.com/haggard/illustrations/images/000/000/#{illustration.id}/original/he_Knelt_164_.jpg?#{illustration.image_updated_at.to_i}"
    assert_equal expected_url, illustration.resolved_image_url(style: :original)
  end

  test "image upload is rejected when S3 credentials are not configured" do
    illustration = Illustration.new(
      edition: @edition,
      name: "Unconfigured upload",
      image_upload: uploaded_file("test.jpg", "image/jpeg", "bytes")
    )

    LegacyS3ImageUploader.stub :configured?, false do
      assert_not illustration.valid?
      assert illustration.errors[:image_upload].any? { |message| message.include?("AWS S3 credentials are missing") }
    end
  end

  test "image upload rejects non-image files" do
    illustration = Illustration.new(
      edition: @edition,
      name: "Wrong type upload",
      image_upload: uploaded_file("payload.html", "text/html", "<html></html>")
    )

    LegacyS3ImageUploader.stub :configured?, true do
      assert_not illustration.valid?
      assert_includes illustration.errors[:image_upload], "must be an image file"
    end
  end

  test "saving without an image upload does not touch S3" do
    upload_stub = lambda do |**| flunk "S3 upload should not be attempted" end

    LegacyS3ImageUploader.stub :upload, upload_stub do
      illustration = Illustration.create!(edition: @edition, name: "No upload")
      assert_nil illustration.image_file_name
    end
  end

  private

  def uploaded_file(filename, content_type, contents)
    tempfile = Tempfile.new("illustration-upload-test")
    tempfile.write(contents)
    tempfile.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: filename,
      type: content_type
    )
  end
end
