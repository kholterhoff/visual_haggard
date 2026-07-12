namespace :hero_covers do
  desc "Generate pre-sized homepage hero cover variants in public/hero-covers"
  task generate: :environment do
    editions = HomeHeroPool.new.reel_editions.uniq(&:id)
    puts "Generating #{HeroCoverVariant::MAX_WIDTH}px hero cover variants for #{editions.size} editions..."

    failures = []
    editions.each do |edition|
      destination = HeroCoverVariant.generate!(edition)
      puts "  ✓ edition ##{edition.id} -> #{destination.relative_path_from(Rails.root)} (#{destination.size / 1024} KB)"
    rescue StandardError => e
      failures << edition
      puts "  ✗ edition ##{edition.id}: #{e.message}"
    end

    puts "Done. #{editions.size - failures.size} generated, #{failures.size} failed."
    puts "Failed editions keep using their original cover URLs on the homepage." if failures.any?
  end
end
