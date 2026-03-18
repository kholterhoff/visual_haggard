require "fileutils"
require "json"
require "nokogiri"
require "uri"
require "shellwords"

class StaticSiteExporter
  include Rails.application.routes.url_helpers

  DEFAULT_HOST = "www.visualhaggard.org".freeze
  DEFAULT_REQUEST_HOST = "127.0.0.1".freeze
  DEFAULT_PAGEFIND_COMMAND = "pagefind".freeze
  PUBLIC_ROOT_FILES = %w[
    404.html
    favicon.ico
    apple-touch-icon.png
    apple-touch-icon-precomposed.png
    robots.txt
  ].freeze

  attr_reader :output_root, :host, :request_host, :warnings, :custom_domain

  def initialize(
    output_root: Rails.root.join("dist"),
    host: DEFAULT_HOST,
    request_host: DEFAULT_REQUEST_HOST,
    precompile_assets: true,
    copy_public_assets: true,
    run_pagefind: true,
    cleanup_compiled_assets: true,
    pagefind_command: ENV.fetch("PAGEFIND_CMD", DEFAULT_PAGEFIND_COMMAND),
    custom_domain: nil,
    out: $stdout
  )
    @output_root = Pathname(output_root)
    @host = host
    @request_host = request_host
    @precompile_assets = precompile_assets
    @copy_public_assets = copy_public_assets
    @run_pagefind = run_pagefind
    @cleanup_compiled_assets = cleanup_compiled_assets
    @pagefind_command = pagefind_command
    @custom_domain = custom_domain.to_s.strip.presence
    @out = out
    @warnings = []
    @asset_replacements = {}
  end

  def export!
    prepare_output_root
    precompile_assets! if @precompile_assets
    copy_public_files! if @copy_public_assets
    write_github_pages_files!
    export_routes!
    index_search! if @run_pagefind
    write_report!
  ensure
    cleanup_compiled_assets! if @precompile_assets && @cleanup_compiled_assets
  end

  def default_url_options
    { host: host }
  end

  def route_specs
    @route_specs ||= begin
      specs = [
        RouteSpec.new(request_path: root_path, output_path: output_path_for(root_path)),
        RouteSpec.new(request_path: biography_path, output_path: output_path_for(biography_path)),
        RouteSpec.new(request_path: editors_statement_path, output_path: output_path_for(editors_statement_path)),
        RouteSpec.new(request_path: search_path, output_path: output_path_for(search_path)),
        RouteSpec.new(request_path: illustrations_path, output_path: output_path_for(illustrations_path)),
        RouteSpec.new(request_path: illustrators_path, output_path: output_path_for(illustrators_path)),
        RouteSpec.new(request_path: novels_path, output_path: output_path_for(novels_path))
      ]

      (2..novel_total_pages).each do |page_number|
        request_path = "#{novels_path}?page=#{page_number}"
        specs << RouteSpec.new(request_path: request_path, output_path: output_path_for(request_path))
      end

      Novel.publicly_visible.order(:id).pluck(:id).each do |id|
        path = novel_path(id)
        specs << RouteSpec.new(request_path: path, output_path: output_path_for(path))
      end

      Edition.includes(:novel).order(:id).find_each do |edition|
        next if edition.synthetic_placeholder?
        next if edition.novel.synthetic_placeholder?

        path = edition_path(edition)
        specs << RouteSpec.new(request_path: path, output_path: output_path_for(path))
      end

      Illustration.browseable.order(:id).pluck(:id).each do |id|
        path = illustration_path(id)
        specs << RouteSpec.new(request_path: path, output_path: output_path_for(path))
      end

      Illustrator.publicly_visible.order(:id).pluck(:id).each do |id|
        path = illustrator_path(id)
        specs << RouteSpec.new(request_path: path, output_path: output_path_for(path))
      end

      specs
    end
  end

  def output_path_for(request_path)
    uri = URI.parse(request_path)
    path = uri.path.presence || "/"
    query = Rack::Utils.parse_nested_query(uri.query)

    if path == novels_path && query["page"].present?
      page_number = query["page"].to_i
      return output_root.join("novels", "page", page_number.to_s, "index.html")
    end

    return output_root.join("index.html") if path == "/"

    segments = path.sub(%r{\A/}, "").split("/").reject(&:blank?)
    output_root.join(*segments, "index.html")
  end

  def rewrite_html_for_static(html)
    document = Nokogiri::HTML5(html)

    document.css("a[href]").each do |node|
      rewritten = rewrite_internal_path(node["href"])
      node["href"] = rewritten if rewritten.present?
    end

    document.css("form[action]").each do |node|
      rewritten = rewrite_internal_path(node["action"])
      node["action"] = rewritten if rewritten.present?
    end

    rewritten_html = document.to_html
    apply_asset_replacements(rewritten_html)
  end

  private

  RouteSpec = Struct.new(:request_path, :output_path, keyword_init: true)

  def prepare_output_root
    FileUtils.rm_rf(output_root)
    FileUtils.mkdir_p(output_root)
  end

  def precompile_assets!
    @out.puts "Precompiling assets for static export..."

    env = {
      "RAILS_ENV" => "production",
      "SECRET_KEY_BASE_DUMMY" => ENV.fetch("SECRET_KEY_BASE_DUMMY", "1"),
      "AWS_EC2_METADATA_DISABLED" => ENV.fetch("AWS_EC2_METADATA_DISABLED", "true")
    }

    success = system(env, "bin/rails", "assets:precompile", chdir: Rails.root.to_s)
    raise "Asset precompile failed" unless success

    load_asset_replacements!
  end

  def copy_public_files!
    PUBLIC_ROOT_FILES.each do |filename|
      source = Rails.root.join("public", filename)
      next unless source.exist?

      destination = output_root.join(filename)
      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp(source, destination)
    end

    assets_source = Rails.root.join("public", "assets")
    return unless assets_source.exist?

    FileUtils.cp_r(assets_source, output_root.join("assets"))
  end

  def write_github_pages_files!
    output_root.join(".nojekyll").write("")
    return if custom_domain.blank?

    output_root.join("CNAME").write("#{custom_domain}\n")
  end

  def export_routes!
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host! request_host

    route_specs.each_with_index do |route_spec, index|
      @out.puts "[#{index + 1}/#{route_specs.size}] Exporting #{route_spec.request_path}"
      session.get(route_spec.request_path)

      unless session.response.successful?
        raise "Static export failed for #{route_spec.request_path} (status #{session.response.status})"
      end

      html = rewrite_html_for_static(session.response.body)
      capture_warnings(route_spec.request_path, html)

      FileUtils.mkdir_p(route_spec.output_path.dirname)
      route_spec.output_path.write(html)
    end
  end

  def index_search!
    @out.puts "Building Pagefind search index..."

    success = system(*Shellwords.split(@pagefind_command.to_s), "--site", output_root.to_s)
    return if success

    warnings << "Pagefind indexing failed. Install the Pagefind binary or set PAGEFIND_CMD before publishing static search."
  rescue Errno::ENOENT
    warnings << "Pagefind binary not found. Install the Pagefind binary or set PAGEFIND_CMD before publishing static search."
  end

  def capture_warnings(request_path, html)
    if html.include?("/rails/active_storage/")
      warnings << "Active Storage route detected in #{request_path}. Static publish requires a durable public image URL."
    end
  end

  def write_report!
    report_lines = []
    report_lines << "Static export completed at #{Time.current.iso8601}"
    report_lines << "Host: #{host}"
    report_lines << "Request host: #{request_host}"
    report_lines << "Exported routes: #{route_specs.size}"
    report_lines << "Custom domain: #{custom_domain}" if custom_domain.present?

    if warnings.any?
      report_lines << ""
      report_lines << "Warnings:"
      warnings.uniq.each do |warning|
        report_lines << "- #{warning}"
      end
    end

    output_root.join("static_export_report.txt").write(report_lines.join("\n") + "\n")
  end

  def cleanup_compiled_assets!
    generated_paths = [
      Rails.root.join("public", "assets"),
      Rails.root.join("tmp", "cache", "assets")
    ]

    removed_any = generated_paths.any?(&:exist?)
    generated_paths.each do |path|
      FileUtils.rm_rf(path) if path.exist?
    end

    @out.puts "Cleaned generated asset directories for local development." if removed_any
  end

  def novel_total_pages
    @novel_total_pages ||= ((Novel.count.to_f / Novel::ARCHIVE_PAGE_SIZE).ceil).clamp(1, Float::INFINITY)
  end

  def load_asset_replacements!
    manifest_path = Dir[Rails.root.join("public", "assets", ".sprockets-manifest-*.json").to_s]
      .max_by { |path| File.mtime(path) }
    return unless manifest_path.present?

    manifest = JSON.parse(File.read(manifest_path))
    logical_assets = manifest.fetch("assets", {})
    files = manifest.fetch("files", {})

    @asset_replacements = files.each_with_object({}) do |(digested_name, metadata), replacements|
      logical_path = metadata["logical_path"]
      next if logical_path.blank?

      current_digested_name = logical_assets[logical_path]
      next if current_digested_name.blank? || current_digested_name == digested_name

      replacements["/assets/#{digested_name}"] = "/assets/#{current_digested_name}"
    end
  end

  def apply_asset_replacements(html)
    return html if @asset_replacements.empty?

    rewritten_html = html.dup
    @asset_replacements.sort_by { |old_path, _| -old_path.length }.each do |old_path, new_path|
      rewritten_html.gsub!(old_path, new_path)
    end
    rewritten_html
  end

  def rewrite_internal_path(value)
    return value if value.blank?
    return value unless value.start_with?("/")

    uri = URI.parse(value)
    return value unless uri.path == novels_path

    query = Rack::Utils.parse_nested_query(uri.query)
    return value if query["page"].blank?

    page_number = query["page"].to_i
    rewritten = page_number <= 1 ? novels_path : "/novels/page/#{page_number}/"
    rewritten += "##{uri.fragment}" if uri.fragment.present?
    rewritten
  rescue URI::InvalidURIError
    value
  end
end
