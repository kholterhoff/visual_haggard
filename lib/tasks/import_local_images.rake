namespace :images do
  desc "Import images from local directory and attach to records"
  task import_local: :environment do
    require 'fileutils'
    
    # CONFIGURATION: Set this to where you'll place your images
    SOURCE_DIR = Rails.root.join('tmp', 'original_images')
    
    puts "="*80
    puts "IMPORTING IMAGES FROM LOCAL DIRECTORY"
    puts "="*80
    puts "Source directory: #{SOURCE_DIR}"
    puts ""
    
    unless Dir.exist?(SOURCE_DIR)
      puts "ERROR: Source directory does not exist!"
      puts "Please create the directory and place your images there:"
      puts "  mkdir -p #{SOURCE_DIR}"
      puts ""
      puts "Then place your images in that directory with their original filenames."
      exit 1
    end
    
    stats = {
      illustrations_success: 0,
      illustrations_failed: 0,
      illustrations_already_attached: 0,
      illustrations_not_found: 0,
      editions_success: 0,
      editions_failed: 0,
      editions_already_attached: 0,
      editions_not_found: 0
    }
    
    # Import illustration images
    import_illustration_images(SOURCE_DIR, stats)
    
    # Import edition cover images
    import_edition_images(SOURCE_DIR, stats)
    
    # Print summary
    print_summary(stats)
  end
  
  def import_illustration_images(source_dir, stats)
    puts "\n" + "-"*80
    puts "IMPORTING ILLUSTRATION IMAGES"
    puts "-"*80
    
    illustrations = Illustration.where.not(image_url: [nil, ''])
    puts "Found #{illustrations.count} illustrations with image filenames\n\n"
    
    illustrations.each_with_index do |illustration, index|
      filename = illustration.image_url
      
      # Skip if already attached
      if illustration.image.attached?
        puts "[#{index + 1}/#{illustrations.count}] #{illustration.name} - Already attached"
        stats[:illustrations_already_attached] += 1
        next
      end
      
      # Look for the file in source directory
      file_path = File.join(source_dir, filename)
      
      unless File.exist?(file_path)
        puts "[#{index + 1}/#{illustrations.count}] #{illustration.name} - File not found: #{filename}"
        stats[:illustrations_not_found] += 1
        next
      end
      
      begin
        puts "[#{index + 1}/#{illustrations.count}] #{illustration.name}"
        puts "  → Attaching: #{filename}"
        
        # Use a simpler approach that works with Rails 7.1
        File.open(file_path, 'rb') do |file|
          illustration.image.attach(
            io: file,
            filename: filename
          )
        end
        
        puts "  ✓ Successfully attached"
        stats[:illustrations_success] += 1
        
      rescue => e
        puts "  ✗ Failed: #{e.message}"
        puts "  #{e.backtrace.first}" if ENV['DEBUG']
        stats[:illustrations_failed] += 1
      end
    end
  end
  
  def import_edition_images(source_dir, stats)
    puts "\n" + "-"*80
    puts "IMPORTING EDITION COVER IMAGES"
    puts "-"*80
    
    editions = Edition.where.not(cover_url: [nil, ''])
    puts "Found #{editions.count} editions with cover filenames\n\n"
    
    editions.each_with_index do |edition, index|
      filename = edition.cover_url
      
      # Skip if already attached
      if edition.cover_image.attached?
        puts "[#{index + 1}/#{editions.count}] #{edition.name} - Already attached"
        stats[:editions_already_attached] += 1
        next
      end
      
      # Look for the file in source directory
      file_path = File.join(source_dir, filename)
      
      unless File.exist?(file_path)
        puts "[#{index + 1}/#{editions.count}] #{edition.name} - File not found: #{filename}"
        stats[:editions_not_found] += 1
        next
      end
      
      begin
        puts "[#{index + 1}/#{editions.count}] #{edition.name}"
        puts "  → Attaching: #{filename}"
        
        # Use a simpler approach that works with Rails 7.1
        File.open(file_path, 'rb') do |file|
          edition.cover_image.attach(
            io: file,
            filename: filename
          )
        end
        
        puts "  ✓ Successfully attached"
        stats[:editions_success] += 1
        
      rescue => e
        puts "  ✗ Failed: #{e.message}"
        puts "  #{e.backtrace.first}" if ENV['DEBUG']
        stats[:editions_failed] += 1
      end
    end
  end
  
  def detect_content_type(filename)
    ext = File.extname(filename).downcase
    case ext
    when '.jpg', '.jpeg'
      'image/jpeg'
    when '.png'
      'image/png'
    when '.gif'
      'image/gif'
    when '.webp'
      'image/webp'
    else
      'image/jpeg' # default
    end
  end
  
  def print_summary(stats)
    puts "\n" + "="*80
    puts "IMPORT SUMMARY"
    puts "="*80
    
    puts "\nIllustrations:"
    puts "  ✓ Successfully imported: #{stats[:illustrations_success]}"
    puts "  ✗ Failed: #{stats[:illustrations_failed]}"
    puts "  ⊙ Already attached: #{stats[:illustrations_already_attached]}"
    puts "  ? File not found: #{stats[:illustrations_not_found]}"
    
    puts "\nEdition Covers:"
    puts "  ✓ Successfully imported: #{stats[:editions_success]}"
    puts "  ✗ Failed: #{stats[:editions_failed]}"
    puts "  ⊙ Already attached: #{stats[:editions_already_attached]}"
    puts "  ? File not found: #{stats[:editions_not_found]}"
    
    total_success = stats[:illustrations_success] + stats[:editions_success]
    total_expected = Illustration.where.not(image_url: [nil, '']).count + 
                     Edition.where.not(cover_url: [nil, '']).count
    
    puts "\nTotal: #{total_success} of #{total_expected} images imported"
    puts "="*80
  end
end