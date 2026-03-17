puts "Seeding database..."

if Rails.env.development?
  admin_email = ENV.fetch("VISUAL_HAGGARD_ADMIN_EMAIL", "admin@example.com")
  admin_password = ENV["VISUAL_HAGGARD_ADMIN_PASSWORD"]

  if admin_password.blank?
    puts "Skipping development admin seed. Set VISUAL_HAGGARD_ADMIN_PASSWORD to create or update #{admin_email}."
  else
    admin = AdminUser.find_or_initialize_by(email: admin_email)
    admin.password = admin_password
    admin.password_confirmation = admin_password
    admin.save!

    puts "Ensured development admin user: #{admin_email}"
  end
else
  puts "No seed data configured for #{Rails.env}."
end

puts "Seeding completed!"
