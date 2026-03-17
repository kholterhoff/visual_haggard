# Configure Ransack for ActiveStorage models and ActsAsTaggableOn.
# These whitelists stay intentionally small because ActiveAdmin is the only caller.

Rails.application.config.to_prepare do
  ActsAsTaggableOn::Tagging.class_eval do
    def self.ransackable_attributes(_auth_object = nil)
      %w[context id tag_id taggable_id taggable_type]
    end

    def self.ransackable_associations(_auth_object = nil)
      %w[tag taggable]
    end
  end

  ActsAsTaggableOn::Tag.class_eval do
    def self.ransackable_attributes(_auth_object = nil)
      %w[id name]
    end

    def self.ransackable_associations(_auth_object = nil)
      %w[taggings]
    end
  end

  ActiveStorage::Attachment.class_eval do
    def self.ransackable_attributes(_auth_object = nil)
      %w[blob_id created_at id name record_id record_type]
    end

    def self.ransackable_associations(_auth_object = nil)
      %w[blob record]
    end
  end

  ActiveStorage::Blob.class_eval do
    def self.ransackable_attributes(_auth_object = nil)
      %w[byte_size content_type created_at filename id]
    end

    def self.ransackable_associations(_auth_object = nil)
      %w[attachments]
    end
  end
end
