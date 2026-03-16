namespace :s3 do
  desc "Migrate existing local images to S3"
  task migrate_images: :environment do
    puts "Starting migration of images to S3..."
    
    # Check if we're in production or have S3 configured
    unless Rails.application.config.active_storage.service == :amazon
      puts "ERROR: Active Storage is not configured to use S3."
      puts "This task should only be run when migrating from local to S3 storage."
      puts "Current service: #{Rails.application.config.active_storage.service}"
      exit 1
    end
    
    migrated_count = 0
    error_count = 0
    
    # Migrate illustration images
    puts "\nMigrating Illustration images..."
    Illustration.find_each do |illustration|
      if illustration.image.attached?
        begin
          # The image is already attached via Active Storage
          # If it's stored locally and we're now using S3, 
          # we need to re-attach it to trigger upload to S3
          
          # Get the current blob
          blob = illustration.image.blob
          
          # Check if it's already on S3
          if blob.service_name == 'amazon'
            puts "  ✓ Illustration ##{illustration.id} already on S3"
          else
            puts "  → Migrating Illustration ##{illustration.id}: #{illustration.name}"
            
            # Download the file content
            file_content = blob.download
            
            # Create a new blob on S3
            new_blob = ActiveStorage::Blob.create_and_upload!(
              io: StringIO.new(file_content),
              filename: blob.filename,
              content_type: blob.content_type,
              service_name: 'amazon'
            )
            
            # Attach the new blob
            illustration.image.attach(new_blob)
            
            # Optionally delete the old blob
            # blob.purge
            
            migrated_count += 1
            puts "  ✓ Migrated successfully"
          end
        rescue => e
          error_count += 1
          puts "  ✗ Error migrating Illustration ##{illustration.id}: #{e.message}"
        end
      end
    end
    
    # Migrate edition cover images
    puts "\nMigrating Edition cover images..."
    Edition.find_each do |edition|
      if edition.cover_image.attached?
        begin
          blob = edition.cover_image.blob
          
          if blob.service_name == 'amazon'
            puts "  ✓ Edition ##{edition.id} cover already on S3"
          else
            puts "  → Migrating Edition ##{edition.id}: #{edition.name}"
            
            file_content = blob.download
            
            new_blob = ActiveStorage::Blob.create_and_upload!(
              io: StringIO.new(file_content),
              filename: blob.filename,
              content_type: blob.content_type,
              service_name: 'amazon'
            )
            
            edition.cover_image.attach(new_blob)
            
            migrated_count += 1
            puts "  ✓ Migrated successfully"
          end
        rescue => e
          error_count += 1
          puts "  ✗ Error migrating Edition ##{edition.id}: #{e.message}"
        end
      end
    end
    
    puts "\n" + "="*50
    puts "Migration complete!"
    puts "Successfully migrated: #{migrated_count} images"
    puts "Errors: #{error_count}" if error_count > 0
    puts "="*50
  end
  
  desc "Verify S3 configuration"
  task verify_config: :environment do
    puts "Checking S3 configuration..."
    puts ""
    
    # Check service configuration
    service = Rails.application.config.active_storage.service
    puts "Active Storage Service: #{service}"
    
    if service == :amazon
      puts "✓ Configured to use Amazon S3"
      
      # Check environment variables
      required_vars = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION', 'S3_BUCKET']
      missing_vars = required_vars.reject { |var| ENV[var].present? }
      
      if missing_vars.empty?
        puts "✓ All required environment variables are set:"
        puts "  - AWS_REGION: #{ENV['AWS_REGION']}"
        puts "  - S3_BUCKET: #{ENV['S3_BUCKET']}"
        puts "  - AWS_ACCESS_KEY_ID: #{ENV['AWS_ACCESS_KEY_ID'][0..5]}..." if ENV['AWS_ACCESS_KEY_ID']
        
        # Try to connect to S3
        begin
          require 'aws-sdk-s3'
          s3 = Aws::S3::Resource.new(
            region: ENV['AWS_REGION'],
            access_key_id: ENV['AWS_ACCESS_KEY_ID'],
            secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
          )
          
          bucket = s3.bucket(ENV['S3_BUCKET'])
          if bucket.exists?
            puts "✓ Successfully connected to S3 bucket: #{ENV['S3_BUCKET']}"
          else
            puts "✗ S3 bucket does not exist: #{ENV['S3_BUCKET']}"
          end
        rescue => e
          puts "✗ Error connecting to S3: #{e.message}"
        end
      else
        puts "✗ Missing required environment variables:"
        missing_vars.each { |var| puts "  - #{var}" }
      end
    elsif service == :local
      puts "ℹ Currently using local storage (development mode)"
      puts "  Images are stored in: #{Rails.root.join('storage')}"
    else
      puts "⚠ Unknown storage service: #{service}"
    end
    
    puts ""
  end
  
  desc "List all attached images and their storage locations"
  task list_images: :environment do
    puts "Listing all attached images..."
    puts ""
    
    total_count = 0
    local_count = 0
    s3_count = 0
    
    puts "Illustration Images:"
    puts "-" * 80
    Illustration.includes(image_attachment: :blob).find_each do |illustration|
      if illustration.image.attached?
        blob = illustration.image.blob
        service = blob.service_name
        size_mb = (blob.byte_size / 1024.0 / 1024.0).round(2)
        
        puts "ID: #{illustration.id.to_s.rjust(4)} | #{illustration.name[0..40].ljust(42)} | #{service.ljust(10)} | #{size_mb} MB"
        
        total_count += 1
        service == 'amazon' ? s3_count += 1 : local_count += 1
      end
    end
    
    puts ""
    puts "Edition Cover Images:"
    puts "-" * 80
    Edition.includes(cover_image_attachment: :blob).find_each do |edition|
      if edition.cover_image.attached?
        blob = edition.cover_image.blob
        service = blob.service_name
        size_mb = (blob.byte_size / 1024.0 / 1024.0).round(2)
        
        puts "ID: #{edition.id.to_s.rjust(4)} | #{edition.name[0..40].ljust(42)} | #{service.ljust(10)} | #{size_mb} MB"
        
        total_count += 1
        service == 'amazon' ? s3_count += 1 : local_count += 1
      end
    end
    
    puts ""
    puts "="*80
    puts "Summary:"
    puts "  Total images: #{total_count}"
    puts "  On S3: #{s3_count}"
    puts "  Local: #{local_count}"
    puts "="*80
  end
end