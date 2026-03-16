namespace :images do
  desc "Import images by matching slugified names to filenames"
  task import_by_slug: :environment do
    require 'active_support/inflector'
    
    image_dir = Rails.root.join('tmp', 'original_images')
    
    unless Dir.exist?(image_dir)
      puts "❌ Directory not found: #{image_dir}"
      exit
    end
    
    # Get all image files
    image_files = Dir.glob(File.join(image_dir, '*')).select { |f| File.file?(f) }
    puts "📁 Found #{image_files.count} files in #{image_dir}"
    puts ""
    
    # Helper to generate slug from text
    def slugify(text)
      return '' if text.blank?
      text.to_s
          .gsub(/['']/,  '')  # Remove apostrophes
          .gsub(/[^\w\s-]/, '')  # Remove non-word chars except spaces and hyphens
          .gsub(/[_\s-]+/, '')  # Remove underscores, spaces, and hyphens
          .downcase
    end
    
    # Helper to check if filename matches slug
    def filename_matches_slug?(filename, slug)
      return false if slug.blank?
      base = slugify(File.basename(filename, '.*'))
      
      # Check if either contains the other (handles partial matches)
      base.include?(slug) || slug.include?(base)
    end
    
    # Helper to find best matching file
    def find_matching_file(files, *search_terms)
      search_terms.compact.each do |term|
        slug = slugify(term)
        next if slug.blank?
        
        # Try exact match first
        exact_match = files.find { |f| File.basename(f, '.*').downcase == slug }
        return exact_match if exact_match
        
        # Try partial match
        partial_match = files.find { |f| filename_matches_slug?(f, slug) }
        return partial_match if partial_match
      end
      nil
    end
    
    attached_count = 0
    skipped_count = 0
    failed_count = 0
    
    puts "🔍 Searching for illustrations to import..."
    puts ""
    
    # Process all illustrations
    Illustration.find_each do |illustration|
      # Skip if already has image
      if illustration.image.attached?
        skipped_count += 1
        next
      end
      
      # Try to find matching file using various name combinations
      edition = illustration.edition
      novel = edition&.novel
      
      search_terms = [
        illustration.name,
        illustration.description,
        edition&.name,
        edition&.long_name,
        novel&.name,
        # Combine novel + edition
        [novel&.name, edition&.name].compact.join(' '),
        [novel&.name, edition&.long_name].compact.join(' ')
      ]
      
      matching_file = find_matching_file(image_files, *search_terms)
      
      if matching_file
        begin
          # Use Rails' standard attach method with file IO
          illustration.image.attach(
            io: File.open(matching_file, 'rb'),
            filename: File.basename(matching_file)
          )
          
          if illustration.image.attached?
            attached_count += 1
            puts "✅ Attached #{File.basename(matching_file)} to Illustration ##{illustration.id}"
            puts "   Novel: #{novel&.name}"
            puts "   Edition: #{edition&.name}"
            puts "   Illustration: #{illustration.name}"
            puts ""
          else
            failed_count += 1
            puts "❌ Failed to attach #{File.basename(matching_file)} to Illustration ##{illustration.id}"
          end
        rescue => e
          failed_count += 1
          puts "❌ Error attaching #{File.basename(matching_file)} to Illustration ##{illustration.id}: #{e.message}"
        end
      end
    end
    
    puts ""
    puts "🔍 Searching for edition covers to import..."
    puts ""
    
    # Process all editions
    Edition.find_each do |edition|
      # Skip if already has cover
      if edition.cover_image.attached?
        skipped_count += 1
        next
      end
      
      # Try to find matching file
      novel = edition.novel
      
      search_terms = [
        edition.name,
        edition.long_name,
        novel&.name,
        # Combine novel + edition + "cover" or "dust jacket"
        [novel&.name, edition&.name, 'cover'].compact.join(' '),
        [novel&.name, edition&.name, 'dustjacket'].compact.join(' '),
        [novel&.name, edition&.long_name, 'cover'].compact.join(' ')
      ]
      
      matching_file = find_matching_file(image_files, *search_terms)
      
      if matching_file
        begin
          # Use Rails' standard attach method with file IO
          edition.cover_image.attach(
            io: File.open(matching_file, 'rb'),
            filename: File.basename(matching_file)
          )
          
          if edition.cover_image.attached?
            attached_count += 1
            puts "✅ Attached #{File.basename(matching_file)} to Edition ##{edition.id}"
            puts "   Novel: #{novel&.name}"
            puts "   Edition: #{edition.name}"
            puts ""
          else
            failed_count += 1
            puts "❌ Failed to attach #{File.basename(matching_file)} to Edition ##{edition.id}"
          end
        rescue => e
          failed_count += 1
          puts "❌ Error attaching #{File.basename(matching_file)} to Edition ##{edition.id}: #{e.message}"
        end
      end
    end
    
    puts ""
    puts "=" * 60
    puts "📊 Import Summary:"
    puts "   ✅ Successfully attached: #{attached_count}"
    puts "   ⏭️  Skipped (already attached): #{skipped_count}"
    puts "   ❌ Failed: #{failed_count}"
    puts "=" * 60
  end
end