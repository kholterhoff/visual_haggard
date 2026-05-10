class OriginalIllustration < ApplicationRecord
  STRING_MAXIMUM = 255

  belongs_to :novel
  has_many :illustrations, dependent: :nullify

  has_one_attached :image, dependent: :purge_later

  validates :novel, :artist, presence: true
  validates :artist, :title, :dimensions, :medium, :source, :year,
            length: { maximum: STRING_MAXIMUM }, allow_blank: true

  def display_title
    title.presence || "Untitled original artwork"
  end

  def display_image_source
    image.attached? ? image : nil
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[artist created_at dimensions id medium novel_id source title updated_at year]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[novel illustrations]
  end
end
