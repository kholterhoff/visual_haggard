require "net/http"

# Locates and generates the pre-sized homepage hero cover images stored in
# public/hero-covers/. The hero reels display covers at most ~320px tall, so
# serving the multi-megabyte archival scans there made the animation take
# seconds to reveal; these variants are a few dozen kilobytes each. Generate
# them with `bin/rails hero_covers:generate` after changing hero covers.
class HeroCoverVariant
  DIRECTORY = "hero-covers".freeze
  # 2x the widest reel column (~280px at desktop widths) so tiles stay crisp
  # on high-density displays.
  MAX_WIDTH = 560

  class << self
    def url_for(edition)
      path = path_for(edition)
      return unless path.exist?

      "/#{DIRECTORY}/#{path.basename}?#{path.mtime.to_i}"
    end

    def path_for(edition)
      root.join("#{edition.id}.jpg")
    end

    def root
      # Tests create editions whose ids collide with generated variants, so
      # keep the test environment pointed at its own scratch directory.
      return Rails.root.join("tmp", "test-hero-covers") if Rails.env.test?

      Rails.root.join("public", DIRECTORY)
    end

    # Downloads the edition's original cover and writes the resized variant.
    # Resizing shells out to macOS `sips` so no extra image tooling is needed
    # on the machine that runs the export/publish workflow.
    def generate!(edition, source_url: nil)
      source_url ||= edition.display_cover_source(style: :original)
      raise ArgumentError, "edition #{edition.id} has no cover URL to fetch" if source_url.blank? || !source_url.is_a?(String)

      FileUtils.mkdir_p(root)

      Tempfile.create(["hero-cover-#{edition.id}", ".img"]) do |download|
        download.binmode
        download.write(fetch(source_url))
        download.flush

        destination = path_for(edition)
        resize!(download.path, destination.to_s)
        destination
      end
    end

    private

    def fetch(url, redirects_remaining = 3)
      raise "too many redirects fetching hero cover" if redirects_remaining.negative?

      response = Net::HTTP.get_response(URI.parse(url))
      case response
      when Net::HTTPSuccess then response.body
      when Net::HTTPRedirection then fetch(response["location"], redirects_remaining - 1)
      else raise "HTTP #{response.code} fetching #{url}"
      end
    end

    def resize!(source_path, destination_path)
      output = IO.popen(
        [
          "sips",
          "--resampleWidth", MAX_WIDTH.to_s,
          "-s", "format", "jpeg",
          "-s", "formatOptions", "65",
          source_path,
          "--out", destination_path
        ],
        err: [:child, :out], &:read
      )
      raise "sips failed: #{output}" unless $?.success?
    end
  end
end
