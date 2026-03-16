namespace :static do
  desc "Export the public archive to dist/ for static hosting"
  task export: :environment do
    output_root = ENV["OUTPUT"].present? ? Pathname(ENV["OUTPUT"]) : Rails.root.join("dist")
    host = ENV.fetch("STATIC_HOST", StaticSiteExporter::DEFAULT_HOST)
    precompile_assets = !%w[0 false no].include?(ENV.fetch("PRECOMPILE_ASSETS", "true").downcase)
    copy_public_assets = !%w[0 false no].include?(ENV.fetch("COPY_PUBLIC_ASSETS", "true").downcase)
    run_pagefind = !%w[0 false no].include?(ENV.fetch("RUN_PAGEFIND", "true").downcase)
    custom_domain = ENV["CUSTOM_DOMAIN"].to_s.strip.presence

    exporter = StaticSiteExporter.new(
      output_root: output_root,
      host: host,
      precompile_assets: precompile_assets,
      copy_public_assets: copy_public_assets,
      run_pagefind: run_pagefind,
      custom_domain: custom_domain
    )

    exporter.export!

    puts
    puts "Static export complete: #{output_root}"
    if exporter.warnings.any?
      puts "Warnings:"
      exporter.warnings.uniq.each do |warning|
        puts "- #{warning}"
      end
    end
  end
end
