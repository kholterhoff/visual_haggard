namespace :images do
  desc "Download all images from Wayback Machine and other sources to local storage"
  task download_all: :environment do
    require 'open-uri'
    require 'fileutils'
    require 'httparty'
    
    puts "="*80
    puts "DOWNLOADING ALL IMAGES TO LOCAL STORAGE"
    puts "="*80
    
    # Ensure storage directory exists
    FileUtils.mkdir_p(Rails.root.join('storage'))
    
    stats = {
      wayback_success: 0,
      wayback_failed: 0,
      s3_public_success: 0,
      s3_public_failed: 0,
      already_attached: 0
    }
    
    # Download images from legacy filename fields (stored in Wayback Machine)
    download_legacy_filename_images(stats)
    
    # Print summary
    puts "\n" + "="*80
    puts "DOWNLOAD SUMMARY"
    puts "="*80
    puts "Wayback Machine Images:"
    puts "  ✓ Successfully downloaded: #{stats[:wayback_success]}"
    puts "  ✗ Failed: #{stats[:wayback_failed]}"
    puts "\nPublic S3 Images:"
    puts "  ✓ Successfully downloaded: #{stats[:s3_public_success]}"
    puts "  ✗ Failed: #{stats[:s3_public_failed]}"
    puts "\nAlready Attached: #{stats[:already_attached]}"
    puts "="*80
  end
  
  def download_legacy_filename_images(stats)
    puts "\n" + "-"*80
    puts "DOWNLOADING IMAGES FROM LEGACY FILENAME FIELDS"
    puts "-"*80
    
    # Download illustration images from image_url field (actually filenames)
    download_illustration_images(stats)
    
    # Download edition cover images from cover_url field (actually filenames)
    download_edition_images(stats)
  end
  
  def download_illustration_images(stats)
    puts "\nProcessing Illustrations with image_url..."
    
    illustrations = Illustration.where.not(image_url: [nil, ''])
    
    puts "Found #{illustrations.count} illustrations with image filenames"
    
    illustrations.each_with_index do |illustration, index|
      begin
        filename = illustration.image_url
        
        # Skip if already has ActiveStorage attachment
        if illustration.image.attached?
          puts "\n[#{index + 1}/#{illustrations.count}] #{illustration.name} - Already attached"
          stats[:already_attached] += 1
          next
        end
        
        puts "\n[#{index + 1}/#{illustrations.count}] #{illustration.name}"
        puts "  Filename: #{filename}"
        
        # Try multiple sources for the image
        downloaded = try_download_from_sources(filename, illustration, :image, stats)
        
        unless downloaded
          puts "  ✗ Failed to download from any source"
        end
        
      rescue => e
        puts "  ✗ Error: #{e.message}"
      end
      
      sleep 1 # Rate limiting
    end
  end
  
  def download_edition_images(stats)
    puts "\nProcessing Editions with cover_url..."
    
    editions = Edition.where.not(cover_url: [nil, ''])
    
    puts "Found #{editions.count} editions with cover filenames"
    
    editions.each_with_index do |edition, index|
      begin
        filename = edition.cover_url
        
        # Skip if already has ActiveStorage attachment
        if edition.cover_image.attached?
          puts "\n[#{index + 1}/#{editions.count}] #{edition.name} - Already attached"
          stats[:already_attached] += 1
          next
        end
        
        puts "\n[#{index + 1}/#{editions.count}] #{edition.name}"
        puts "  Filename: #{filename}"
        
        # Try multiple sources for the image
        downloaded = try_download_from_sources(filename, edition, :cover_image, stats)
        
        unless downloaded
          puts "  ✗ Failed to download from any source"
        end
        
      rescue => e
        puts "  ✗ Error: #{e.message}"
      end
      
      sleep 1 # Rate limiting
    end
  end
  
  def try_download_from_sources(filename, record, attachment_name, stats)
    # Try different URL patterns to find the image
    
    # Source 1: Wayback Machine - original visualhaggard.org
    wayback_urls = [
      "https://web.archive.org/web/20220815220555/http://www.visualhaggard.org/images/#{filename}",
      "https://web.archive.org/web/20220815220555/http://www.visualhaggard.org/uploads/#{filename}",
      "https://web.archive.org/web/20220815220555/http://www.visualhaggard.org/assets/#{filename}",
      "https://web.archive.org/web/20220815210913/http://www.visualhaggard.org/images/#{filename}",
      "https://web.archive.org/web/20220815210913/http://www.visualhaggard.org/uploads/#{filename}"
    ]
    
    wayback_urls.each do |url|
      puts "  → Trying Wayback: #{url}"
      if download_and_attach_image(url, record, attachment_name)
        puts "  ✓ Downloaded from Wayback Machine"
        stats[:wayback_success] += 1
        return true
      end
    end
    
    # Source 2: Try public S3 bucket (if it exists and is public)
    s3_urls = [
      "https://visual-haggard-production.s3.amazonaws.com/#{filename}",
      "https://visual-haggard-production.s3.us-east-1.amazonaws.com/#{filename}",
      "https://s3.amazonaws.com/visual-haggard-production/#{filename}"
    ]
    
    s3_urls.each do |url|
      puts "  → Trying S3: #{url}"
      if download_and_attach_image(url, record, attachment_name)
        puts "  ✓ Downloaded from S3"
        stats[:s3_public_success] += 1
        return true
      end
    end
    
    stats[:wayback_failed] += 1
    false
  end
  
  def download_and_attach_image(url, record, attachment_name)
    begin
      response = HTTParty.get(url, timeout: 30, follow_redirects: true)
      
      return false unless response.success?
      
      # Create a temporary file
      tempfile = Tempfile.new(['image', File.extname(url)])
      tempfile.binmode
      tempfile.write(response.body)
      tempfile.rewind
      
      # Attach to record
      record.send(attachment_name).attach(
        io: tempfile,
        filename: File.basename(url),
        content_type: response.headers['content-type'] || 'image/jpeg'
      )
      
      tempfile.close
      tempfile.unlink
      
      return true
    rescue => e
      # Silently fail and try next source
      return false
    end
  end
end