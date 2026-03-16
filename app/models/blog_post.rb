class BlogPost < ApplicationRecord
  belongs_to :illustration, optional: true
  belongs_to :novel, optional: true
  belongs_to :edition, optional: true
  
  validates :title, presence: true
  validates :content, presence: true
  
  include PgSearch::Model
  pg_search_scope :search_by_content,
    against: [:title, :content, :author],
    using: {
      tsearch: { prefix: true }
    }

  # Define searchable associations for Ransack (used by ActiveAdmin)
  def self.ransackable_associations(auth_object = nil)
    ["edition", "illustration", "novel"]
  end

  # Define searchable attributes for Ransack (used by ActiveAdmin)
  def self.ransackable_attributes(auth_object = nil)
    ["author", "content", "created_at", "edition_id", "id", "illustration_id", "novel_id", "published_at", "title", "updated_at"]
  end
end
