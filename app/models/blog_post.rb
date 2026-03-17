class BlogPost < ApplicationRecord
  STRING_MAXIMUM = 255
  CONTENT_MAXIMUM = 100_000

  belongs_to :illustration, optional: true
  belongs_to :novel, optional: true
  belongs_to :edition, optional: true

  validates :title, presence: true, length: { maximum: STRING_MAXIMUM }
  validates :author, length: { maximum: STRING_MAXIMUM }, allow_blank: true
  validates :content, presence: true, length: { maximum: CONTENT_MAXIMUM }

  include PgSearch::Model
  pg_search_scope :search_by_content,
    against: [:title, :content, :author],
    using: {
      tsearch: { prefix: true }
    }

  def self.ransackable_associations(_auth_object = nil)
    %w[edition illustration novel]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[author content created_at edition_id id illustration_id novel_id title updated_at]
  end
end
