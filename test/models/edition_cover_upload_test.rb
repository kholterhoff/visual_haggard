require "test_helper"
require "minitest/mock"

class EditionCoverUploadTest < ActiveSupport::TestCase
  setup do
    @novel = Novel.create!(name: "Cover Upload Novel")
  end

  test "saving with a cover upload stores it in the legacy S3 bucket and fills legacy columns" do
    uploaded_calls = []
    upload_stub = lambda do |key:, io:, content_type:|
      uploaded_calls << { key: key, bytes: io.read, content_type: content_type }
    end

    edition = nil
    LegacyS3ImageUploader.stub :configured?, true do
      LegacyS3ImageUploader.stub :upload, upload_stub do
        edition = Edition.create!(
          novel: @novel,
          name: "Uploaded Cover Edition",
          cover_image_upload: uploaded_file("dust jacket(1).jpg", "image/jpeg", "jpeg-bytes")
        )
      end
    end

    edition.reload
    assert_equal 1, uploaded_calls.length
    upload = uploaded_calls.first
    assert_equal "editions/images/000/000/#{edition.id}/original/dust_jacket_1_.jpg", upload[:key]
    assert_equal "jpeg-bytes", upload[:bytes]
    assert_equal "image/jpeg", upload[:content_type]

    assert_equal "dust_jacket_1_.jpg", edition.image_file_name
    assert_equal "image/jpeg", edition.image_content_type
    assert_equal "jpeg-bytes".bytesize, edition.image_file_size
    assert_predicate edition.image_updated_at, :present?

    expected_url = "https://s3-us-west-2.amazonaws.com/haggard/editions/images/000/000/#{edition.id}/original/dust_jacket_1_.jpg?#{edition.image_updated_at.to_i}"
    assert_equal expected_url, edition.resolved_cover_url(style: :original)
  end

  test "cover upload is rejected when S3 credentials are not configured" do
    edition = Edition.new(
      novel: @novel,
      name: "Unconfigured Cover Edition",
      cover_image_upload: uploaded_file("cover.jpg", "image/jpeg", "bytes")
    )

    LegacyS3ImageUploader.stub :configured?, false do
      assert_not edition.valid?
      assert edition.errors[:cover_image_upload].any? { |message| message.include?("AWS S3 credentials are missing") }
    end
  end

  test "cover upload rejects non-image files" do
    edition = Edition.new(
      novel: @novel,
      name: "Wrong Type Cover Edition",
      cover_image_upload: uploaded_file("payload.html", "text/html", "<html></html>")
    )

    LegacyS3ImageUploader.stub :configured?, true do
      assert_not edition.valid?
      assert_includes edition.errors[:cover_image_upload], "must be an image file"
    end
  end

  test "saving without a cover upload does not touch S3" do
    upload_stub = lambda do |**| flunk "S3 upload should not be attempted" end

    LegacyS3ImageUploader.stub :upload, upload_stub do
      edition = Edition.create!(novel: @novel, name: "No Cover Edition")
      assert_nil edition.image_file_name
    end
  end

  private

  def uploaded_file(filename, content_type, contents)
    tempfile = Tempfile.new("edition-cover-upload-test")
    tempfile.write(contents)
    tempfile.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: filename,
      type: content_type
    )
  end
end
