module NovelsHelper
  def novel_description_includes_further_reading_heading?(description)
    return false if description.blank?

    description.match?(%r{<h[1-6][^>]*>\s*Further\s+Reading\s*</h[1-6]>}i)
  end
end
