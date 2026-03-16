# Configure Ransack for ActiveStorage models and ActsAsTaggableOn
# This is required when using ActiveAdmin with file attachments and tagging

# Wait for ActsAsTaggableOn to be loaded before configuring
Rails.application.config.to_prepare do
  ActsAsTaggableOn::Tagging.class_eval do
    def self.ransackable_attributes(auth_object = nil)
      ["context", "created_at", "id", "tag_id", "taggable_id", "taggable_type", "tagger_id", "tagger_type", "tenant"]
    end

    def self.ransackable_associations(auth_object = nil)
      ["tag", "taggable", "tagger"]
    end
  end

  ActsAsTaggableOn::Tag.class_eval do
    def self.ransackable_attributes(auth_object = nil)
      ["id", "name", "taggings_count"]
    end

    def self.ransackable_associations(auth_object = nil)
      ["taggings"]
    end
  end
  
  ActiveStorage::Attachment.class_eval do
    def self.ransackable_attributes(auth_object = nil)
      ["blob_id", "created_at", "id", "name", "record_id", "record_type"]
    end

    def self.ransackable_associations(auth_object = nil)
      ["blob", "record"]
    end
  end

  ActiveStorage::Blob.class_eval do
    def self.ransackable_attributes(auth_object = nil)
      ["byte_size", "checksum", "content_type", "created_at", "filename", "id", "key", "metadata"]
    end

    def self.ransackable_associations(auth_object = nil)
      ["attachments"]
    end
  end
end
