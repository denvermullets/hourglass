# Create a default server for development
if Rails.env.development?
  admin = User.find_or_create_by!(username: "admin") do |u|
    u.email_address = "admin@hourglass.dev"
    u.password = "password123"
    u.display_name = "Admin"
  end

  server = Server.find_or_create_by!(name: "Hourglass HQ") do |s|
    s.description = "The default development server"
    s.owner = admin
  end

  server.memberships.find_or_create_by!(user: admin) do |m|
    m.role = :owner
  end

  puts "Seeded: admin user (admin / password123) + Hourglass HQ server"
end
