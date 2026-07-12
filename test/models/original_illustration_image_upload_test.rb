require "test_helper"
require "minitest/mock"

class OriginalIllustrationImageUploadTest < ActiveSupport::TestCase
  setup do
    @novel = Novel.create!(name: "Original Upload Novel")
    @illustrator = Illustrator.create!(name: "Original Upload Artist")
  end

  test "saving with an image upload stores it in the legacy S3 bucket and fills image_url" do
    uploaded_calls = []
    upload_stub = lambda do |key:, io:, content_type:|
      uploaded_calls << { key: key, bytes: io.read, content_type: content_type }
    end

    original = nil
    LegacyS3ImageUploader.stub :configured?, true do
      LegacyS3ImageUploader.stub :upload, upload_stub do
        original = OriginalIllustration.create!(
          novel: @novel,
          illustrator: @illustrator,
          title: "Uploaded original artwork",
          image_upload: uploaded_file("study (final).jpg", "image/jpeg", "jpeg-bytes")
        )
      end
    end

    original.reload
    assert_equal 1, uploaded_calls.length
    upload = uploaded_calls.first
    expected_key = "original_illustrations/images/000/000/#{original.id}/original/study__final_.jpg"
    assert_equal expected_key, upload[:key]
    assert_equal "jpeg-bytes", upload[:bytes]
    assert_equal "image/jpeg", upload[:content_type]

    assert_match %r{\Ahttps://s3-us-west-2\.amazonaws\.com/haggard/#{Regexp.escape(expected_key)}\?\d+\z}, original.image_url
    assert_equal original.image_url, original.display_image_source
  end

  test "image upload is rejected when S3 credentials are not configured" do
    original = OriginalIllustration.new(
      novel: @novel,
      illustrator: @illustrator,
      image_upload: uploaded_file("study.jpg", "image/jpeg", "bytes")
    )

    LegacyS3ImageUploader.stub :configured?, false do
      assert_not original.valid?
      assert original.errors[:image_upload].any? { |message| message.include?("AWS S3 credentials are missing") }
    end
  end

  test "image upload rejects non-image files" do
    original = OriginalIllustration.new(
      novel: @novel,
      illustrator: @illustrator,
      image_upload: uploaded_file("payload.html", "text/html", "<html></html>")
    )

    LegacyS3ImageUploader.stub :configured?, true do
      assert_not original.valid?
      assert_includes original.errors[:image_upload], "must be an image file"
    end
  end

  test "saving without an image upload does not touch S3 or image_url" do
    upload_stub = lambda do |**| flunk "S3 upload should not be attempted" end

    LegacyS3ImageUploader.stub :upload, upload_stub do
      original = OriginalIllustration.create!(
        novel: @novel,
        illustrator: @illustrator,
        image_url: "https://example.com/manual.jpg"
      )
      assert_equal "https://example.com/manual.jpg", original.image_url
    end
  end

  private

  def uploaded_file(filename, content_type, contents)
    tempfile = Tempfile.new("original-illustration-upload-test")
    tempfile.write(contents)
    tempfile.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: filename,
      type: content_type
    )
  end
end
