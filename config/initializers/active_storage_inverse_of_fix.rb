Rails.application.config.after_initialize do
  # Avoid inverse-association errors when attaching to polymorphic records.
  ActiveStorage::Attachment.class_eval do
    belongs_to :record, polymorphic: true, touch: true, inverse_of: false
    belongs_to :blob, class_name: "ActiveStorage::Blob"
  end
end
