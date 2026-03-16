puts "Seeding database..."

if Rails.env.development?
  AdminUser.find_or_create_by!(email: "admin@example.com") do |admin|
    admin.password = "password"
    admin.password_confirmation = "password"
  end

  puts "Ensured development admin user: admin@example.com / password"
else
  puts "No seed data configured for #{Rails.env}."
end

puts "Seeding completed!"
