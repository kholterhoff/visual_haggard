namespace :images do
  desc "Attach images from DB URL fields (alias for images:attach_from_db)"
  task attach: :attach_from_db
end
