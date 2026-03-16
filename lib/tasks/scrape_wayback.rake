namespace :scrape do
  desc "Scrape Visual Haggard content from Wayback Machine"
  task wayback: :environment do
    require 'httparty'
    require 'nokogiri'
    require 'open-uri'
    
    BASE_URL = 'https://web.archive.org/web/20220815220555/http://www.visualhaggard.org'
    
    puts "Starting to scrape Visual Haggard from Wayback Machine..."
    puts "Base URL: #{BASE_URL}"
    
    # Scrape in order: illustrators -> novels -> editions -> illustrations -> blog posts
    scrape_illustrators
    scrape_novels
    scrape_editions
    scrape_illustrations
    scrape_blog_posts
    
    puts "\n" + "="*80
    puts "Scraping completed!"
    puts "Summary:"
    puts "  Novels: #{Novel.count}"
    puts "  Editions: #{Edition.count}"
    puts "  Illustrators: #{Illustrator.count}"
    puts "  Illustrations: #{Illustration.count}"
    puts "  Blog Posts: #{BlogPost.count}"
    puts "="*80
  end
  
  def normalize_wayback_url(url)
    return nil unless url.present?
    
    # If URL already contains web.archive.org, extract the original URL
    if url.include?('web.archive.org')
      # Match pattern: /web/TIMESTAMP/ORIGINAL_URL
      if url =~ %r{/web/\d+/(https?://[^/]+/.+)$}
        url = $1
      elsif url =~ %r{/web/\d+/(/.+)$}
        # Relative path after timestamp
        url = "http://www.visualhaggard.org#{$1}"
      end
    end
    
    # Handle relative URLs
    if url.start_with?('/')
      url = "http://www.visualhaggard.org#{url}"
    elsif !url.start_with?('http')
      url = "http://www.visualhaggard.org/#{url}"
    end
    
    # Ensure we're using visualhaggard.org domain
    url = url.gsub('https://www.visualhaggard.org', 'http://www.visualhaggard.org')
    
    # Wrap in our specific Wayback snapshot
    "https://web.archive.org/web/20220815220555/#{url}"
  end
  
  def fetch_page(url)
    url = normalize_wayback_url(url)
    puts "  Fetching: #{url}"
    response = HTTParty.get(url, timeout: 30, follow_redirects: true)
    if response.success?
      Nokogiri::HTML(response.body)
    else
      puts "  ERROR: Failed to fetch #{url} (Status: #{response.code})"
      nil
    end
  rescue => e
    puts "  ERROR: Exception fetching #{url}: #{e.message}"
    nil
  end
  
  def download_image(url, record, attachment_name = :image)
    return unless url.present?
    
    url = normalize_wayback_url(url)
    puts "    Downloading image: #{url}"
    
    begin
      URI.open(url, read_timeout: 30) do |file|
        filename = File.basename(URI.parse(url).path)
        filename = "image_#{Time.now.to_i}.jpg" if filename.blank? || filename == '/'
        
        record.send(attachment_name).attach(
          io: file,
          filename: filename,
          content_type: file.content_type || 'image/jpeg'
        )
        puts "    ✓ Image attached successfully"
        true
      end
    rescue => e
      puts "    ✗ Failed to download image: #{e.message}"
      false
    end
  end
  
  def scrape_illustrators
    puts "\n" + "="*80
    puts "SCRAPING ILLUSTRATORS"
    puts "="*80
    
    url = "#{BASE_URL}/illustrators"
    doc = fetch_page(url)
    return unless doc
    
    # Look for illustrator links or listings
    illustrator_links = doc.css('a[href*="/illustrators/"]').map { |a| a['href'] }.uniq
    
    if illustrator_links.empty?
      puts "  No illustrator links found, trying alternative selectors..."
      # Try different selectors based on common patterns
      illustrator_links = doc.css('.illustrator-link, .artist-link').map { |a| a['href'] }.uniq
    end
    
    puts "  Found #{illustrator_links.count} illustrator links"
    
    illustrator_links.each_with_index do |link, index|
      next unless link
      
      full_url = link.start_with?('http') ? link : "#{BASE_URL}#{link}"
      illustrator_doc = fetch_page(full_url)
      next unless illustrator_doc
      
      name = illustrator_doc.css('h1, .illustrator-name, .artist-name').first&.text&.strip
      name ||= link.split('/').last.gsub(/[-_]/, ' ').titleize
      
      bio = illustrator_doc.css('.bio, .biography, .description, p').first&.text&.strip
      
      illustrator = Illustrator.find_or_create_by(name: name) do |i|
        i.bio = bio
      end
      
      puts "  [#{index + 1}/#{illustrator_links.count}] #{illustrator.persisted? ? '✓' : '✗'} #{name}"
    end
    
    # If no illustrators found via links, create some default ones
    if Illustrator.count == 0
      puts "  Creating default illustrators..."
      default_illustrators = [
        { name: "Maurice Greiffenhagen", bio: "British illustrator known for his work on Haggard's novels" },
        { name: "Charles H. M. Kerr", bio: "Illustrator of early Haggard editions" },
        { name: "Unknown", bio: "Illustrator information not available" }
      ]
      
      default_illustrators.each do |data|
        Illustrator.find_or_create_by(name: data[:name]) do |i|
          i.bio = data[:bio]
        end
        puts "  ✓ #{data[:name]}"
      end
    end
    
    puts "  Total illustrators: #{Illustrator.count}"
  end
  
  def scrape_novels
    puts "\n" + "="*80
    puts "SCRAPING NOVELS"
    puts "="*80
    
    url = "#{BASE_URL}/novels"
    doc = fetch_page(url)
    return unless doc
    
    # Look for novel links
    novel_links = doc.css('a[href*="/novels/"]').map { |a| a['href'] }.uniq.reject { |l| l.include?('/editions') }
    
    if novel_links.empty?
      puts "  No novel links found, trying alternative approach..."
      novel_links = doc.css('.novel-link, .book-link').map { |a| a['href'] }.uniq
    end
    
    puts "  Found #{novel_links.count} novel links"
    
    novel_links.each_with_index do |link, index|
      next unless link
      
      full_url = link.start_with?('http') ? link : "#{BASE_URL}#{link}"
      novel_doc = fetch_page(full_url)
      next unless novel_doc
      
      name = novel_doc.css('h1, .novel-title, .book-title').first&.text&.strip
      name ||= link.split('/').last.gsub(/[-_]/, ' ').titleize
      
      description = novel_doc.css('.description, .summary, .synopsis, p').first&.text&.strip
      
      novel = Novel.find_or_create_by(name: name) do |n|
        n.description = description
      end
      
      puts "  [#{index + 1}/#{novel_links.count}] #{novel.persisted? ? '✓' : '✗'} #{name}"
    end
    
    # If no novels found, create some famous Haggard novels
    if Novel.count == 0
      puts "  Creating default novels..."
      default_novels = [
        { name: "King Solomon's Mines", description: "An adventure novel about a search for treasure in Africa" },
        { name: "She", description: "A fantasy adventure novel about an immortal queen" },
        { name: "Allan Quatermain", description: "A sequel to King Solomon's Mines" },
        { name: "Ayesha: The Return of She", description: "A sequel to She" },
        { name: "The World's Desire", description: "A fantasy novel co-written with Andrew Lang" }
      ]
      
      default_novels.each do |data|
        Novel.find_or_create_by(name: data[:name]) do |n|
          n.description = data[:description]
        end
        puts "  ✓ #{data[:name]}"
      end
    end
    
    puts "  Total novels: #{Novel.count}"
  end
  
  def scrape_editions
    puts "\n" + "="*80
    puts "SCRAPING EDITIONS"
    puts "="*80
    
    Novel.find_each do |novel|
      puts "\n  Processing editions for: #{novel.name}"
      
      # Try to find editions page for this novel
      novel_slug = novel.name.parameterize
      url = "#{BASE_URL}/novels/#{novel_slug}/editions"
      doc = fetch_page(url)
      
      if doc
        edition_links = doc.css('a[href*="/editions/"]').map { |a| a['href'] }.uniq
        puts "    Found #{edition_links.count} edition links"
        
        edition_links.each do |link|
          next unless link
          
          full_url = link.start_with?('http') ? link : "#{BASE_URL}#{link}"
          edition_doc = fetch_page(full_url)
          next unless edition_doc
          
          name = edition_doc.css('h1, .edition-title').first&.text&.strip
          publisher = edition_doc.css('.publisher').first&.text&.strip
          publication_date = edition_doc.css('.publication-date, .date').first&.text&.strip
          publication_city = edition_doc.css('.publication-city, .city').first&.text&.strip
          
          # Look for cover image
          cover_img = edition_doc.css('img.cover, img.edition-cover, .cover img').first
          cover_url = cover_img&.[]('src')
          
          edition = Edition.find_or_create_by(novel: novel, name: name || "Edition #{Time.now.to_i}") do |e|
            e.publisher = publisher
            e.publication_date = publication_date
            e.publication_city = publication_city
            e.cover_url = cover_url
          end
          
          # Download cover image if available
          if cover_url && !edition.cover_image.attached?
            download_image(cover_url, edition, :cover_image)
          end
          
          puts "    ✓ #{edition.name}"
        end
      else
        puts "    No editions page found, skipping placeholder edition creation"
      end
    end
    
    puts "\n  Total editions: #{Edition.count}"
  end
  
  def scrape_illustrations
    puts "\n" + "="*80
    puts "SCRAPING ILLUSTRATIONS"
    puts "="*80
    
    # Try to find illustrations index page
    url = "#{BASE_URL}/illustrations"
    doc = fetch_page(url)
    
    if doc
      illustration_links = doc.css('a[href*="/illustrations/"]').map { |a| a['href'] }.uniq
      puts "  Found #{illustration_links.count} illustration links"
      
      illustration_links.each_with_index do |link, index|
        next unless link
        
        full_url = link.start_with?('http') ? link : "#{BASE_URL}#{link}"
        ill_doc = fetch_page(full_url)
        next unless ill_doc
        
        name = ill_doc.css('h1, .illustration-title').first&.text&.strip
        name ||= "Illustration #{index + 1}"
        
        description = ill_doc.css('.description, .caption, p').first&.text&.strip
        artist = ill_doc.css('.artist, .illustrator').first&.text&.strip
        page_number = ill_doc.css('.page-number').first&.text&.strip
        
        # Find the illustration image
        img = ill_doc.css('img.illustration, .illustration img, img[src*="illustration"]').first
        image_url = img&.[]('src')
        
        # Find or create illustrator
        illustrator = if artist.present?
          Illustrator.find_or_create_by(name: artist)
        else
          Illustrator.find_or_create_by(name: "Unknown")
        end
        
        # Try to associate with an edition (use first available for now)
        edition = Edition.first
        next unless edition
        
        illustration = Illustration.find_or_create_by(
          name: name,
          edition: edition,
          illustrator: illustrator
        ) do |i|
          i.description = description
          i.page_number = page_number
          i.image_url = image_url
        end
        
        # Download illustration image
        if image_url && !illustration.image.attached?
          download_image(image_url, illustration, :image)
        end
        
        puts "  [#{index + 1}/#{illustration_links.count}] ✓ #{name}"
      end
    else
      puts "  No illustrations index found, trying to scrape from edition pages..."
      
      # Try to find illustrations within edition pages
      Edition.find_each do |edition|
        puts "  Checking edition: #{edition.name}"
        
        # Look for images in the edition's novel pages
        novel_slug = edition.novel.name.parameterize
        edition_slug = edition.name.parameterize
        
        # Try various URL patterns
        urls_to_try = [
          "#{BASE_URL}/novels/#{novel_slug}/editions/#{edition_slug}",
          "#{BASE_URL}/editions/#{edition_slug}",
          "#{BASE_URL}/novels/#{novel_slug}"
        ]
        
        urls_to_try.each do |url|
          doc = fetch_page(url)
          next unless doc
          
          # Find all images that might be illustrations
          images = doc.css('img').select do |img|
            src = img['src']
            src && (src.include?('illustration') || src.include?('image') || src.include?('fig'))
          end
          
          images.each_with_index do |img, idx|
            image_url = img['src']
            alt_text = img['alt'] || "Illustration #{idx + 1}"
            
            illustrator = Illustrator.find_or_create_by(name: "Unknown")
            
            illustration = Illustration.find_or_create_by(
              name: alt_text,
              edition: edition,
              illustrator: illustrator
            ) do |i|
              i.image_url = image_url
            end
            
            if !illustration.image.attached?
              download_image(image_url, illustration, :image)
            end
            
            puts "    ✓ #{alt_text}"
          end
          
          break if images.any?
        end
      end
    end
    
    puts "\n  Total illustrations: #{Illustration.count}"
  end
  
  def scrape_blog_posts
    puts "\n" + "="*80
    puts "SCRAPING BLOG POSTS"
    puts "="*80
    
    url = "#{BASE_URL}/blog"
    doc = fetch_page(url)
    
    if doc
      post_links = doc.css('a[href*="/blog/"], a[href*="/posts/"]').map { |a| a['href'] }.uniq
      puts "  Found #{post_links.count} blog post links"
      
      post_links.each_with_index do |link, index|
        next unless link
        
        full_url = link.start_with?('http') ? link : "#{BASE_URL}#{link}"
        post_doc = fetch_page(full_url)
        next unless post_doc
        
        title = post_doc.css('h1, .post-title, .entry-title').first&.text&.strip
        title ||= "Blog Post #{index + 1}"
        
        author = post_doc.css('.author, .byline').first&.text&.strip || "Unknown"
        content = post_doc.css('.post-content, .entry-content, article').first&.text&.strip
        
        # Try to associate with an illustration and edition
        illustration = Illustration.first
        edition = Edition.first
        novel = Novel.first
        
        next unless illustration && edition && novel
        
        blog_post = BlogPost.find_or_create_by(
          title: title,
          illustration: illustration,
          edition: edition,
          novel: novel
        ) do |bp|
          bp.author = author
          bp.content = content
        end
        
        puts "  [#{index + 1}/#{post_links.count}] ✓ #{title}"
      end
    else
      puts "  No blog page found"
    end
    
    puts "  Total blog posts: #{BlogPost.count}"
  end
end
