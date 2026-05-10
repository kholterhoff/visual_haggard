class OriginalIllustration < ApplicationRecord
  STRING_MAXIMUM = 255

  belongs_to :novel
  belongs_to :illustrator
  has_many :illustrations, dependent: :nullify

  has_one_attached :image, dependent: :purge_later

  validates :novel, :illustrator, presence: true
  validates :title, :dimensions, :medium, :source, :year,
            length: { maximum: STRING_MAXIMUM }, allow_blank: true

  def display_title
    title.presence || "Untitled original artwork"
  end

  def display_image_source
    image.attached? ? image : nil
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at dimensions id illustrator_id medium novel_id source title updated_at year]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[novel illustrator illustrations]
  end
end
