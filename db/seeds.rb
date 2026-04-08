# Seed data for EventNest development
# DO NOT MODIFY - evaluation scripts depend on this data

puts "Seeding database..."

# Skip model callbacks during seeding to avoid cascade issues
Event.skip_callback(:save, :before, :geocode_venue)
Event.skip_callback(:create, :after, :send_organizer_confirmation)
Event.skip_callback(:update, :after, :notify_attendees_if_cancelled)
Event.skip_callback(:update, :after, :update_search_index)

Order.skip_callback(:create, :before, :generate_confirmation_number)
Order.skip_callback(:create, :before, :calculate_total)
Order.skip_callback(:create, :after, :reserve_ticket_inventory)
Order.skip_callback(:create, :after, :create_pending_payment)
Order.skip_callback(:create, :after, :send_confirmation_email)
Order.skip_callback(:create, :after, :track_analytics)
Order.skip_callback(:update, :after, :handle_status_change)
Order.skip_callback(:update, :after, :sync_with_crm)

organizer1 = User.create!(
  name: "Priya Mehta",
  email: "priya@eventnest.dev",
  password: "password123",
  password_confirmation: "password123",
  role: "organizer"
)

organizer2 = User.create!(
  name: "Rahul Sharma",
  email: "rahul@eventnest.dev",
  password: "password123",
  password_confirmation: "password123",
  role: "organizer"
)

attendee1 = User.create!(
  name: "Ananya Gupta",
  email: "ananya@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: "attendee"
)

attendee2 = User.create!(
  name: "Vikram Patel",
  email: "vikram@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: "attendee"
)

attendee3 = User.create!(
  name: "Sneha Reddy",
  email: "sneha@example.com",
  password: "password123",
  password_confirmation: "password123",
  role: "attendee"
)

music_fest = Event.create!(
  title: "Mumbai Indie Music Festival 2025",
  description: "A two-day celebration of independent music featuring artists from across India.",
  venue: "Bandra Fort Amphitheatre, Mumbai",
  city: "Mumbai",
  starts_at: 3.weeks.from_now,
  ends_at: 3.weeks.from_now + 2.days,
  status: "published",
  category: "music",
  max_capacity: 500,
  user: organizer1
)

tech_conf = Event.create!(
  title: "RailsConf India 2025",
  description: "The premier Ruby on Rails conference in India.",
  venue: "Bengaluru International Exhibition Centre, Bengaluru",
  city: "Bengaluru",
  starts_at: 5.weeks.from_now,
  ends_at: 5.weeks.from_now + 3.days,
  status: "published",
  category: "conference",
  max_capacity: 300,
  user: organizer1
)

workshop = Event.create!(
  title: "Advanced PostgreSQL Workshop",
  description: "Hands-on workshop covering advanced PostgreSQL features.",
  venue: "WeWork BKC, Mumbai",
  city: "Mumbai",
  starts_at: 2.weeks.from_now,
  ends_at: 2.weeks.from_now + 8.hours,
  status: "published",
  category: "workshop",
  max_capacity: 40,
  user: organizer2
)

Event.create!(
  title: "Untitled Yoga Retreat",
  description: "Draft event - not yet published",
  venue: "Rishikesh, Uttarakhand",
  city: "Rishikesh",
  starts_at: 8.weeks.from_now,
  ends_at: 8.weeks.from_now + 3.days,
  status: "draft",
  category: "workshop",
  user: organizer2
)

Event.create!(
  title: "Diwali Night Market 2024",
  description: "A festive evening of shopping, food, and performances.",
  venue: "Jawaharlal Nehru Stadium, Delhi",
  city: "Delhi",
  starts_at: 2.months.ago,
  ends_at: 2.months.ago + 6.hours,
  status: "published",
  category: "music",
  max_capacity: 1000,
  user: organizer1
)

music_early = TicketTier.create!(event: music_fest, name: "Early Bird", price: 999.00, quantity: 100, sold_count: 98, sales_start: 2.months.ago, sales_end: 1.week.from_now)
music_regular = TicketTier.create!(event: music_fest, name: "Regular", price: 1499.00, quantity: 200, sold_count: 45, sales_start: 1.month.ago, sales_end: 3.weeks.from_now)
music_vip = TicketTier.create!(event: music_fest, name: "VIP Lounge", price: 3999.00, quantity: 50, sold_count: 50, sales_start: 2.months.ago, sales_end: 3.weeks.from_now)

conf_standard = TicketTier.create!(event: tech_conf, name: "Standard", price: 2499.00, quantity: 200, sold_count: 120, sales_start: 3.months.ago, sales_end: 5.weeks.from_now)
conf_premium = TicketTier.create!(event: tech_conf, name: "Premium (with Workshop)", price: 4999.00, quantity: 80, sold_count: 35, sales_start: 3.months.ago, sales_end: 5.weeks.from_now)
conf_student = TicketTier.create!(event: tech_conf, name: "Student", price: 499.00, quantity: 50, sold_count: 50, sales_start: 3.months.ago, sales_end: 4.weeks.from_now)

workshop_tier = TicketTier.create!(event: workshop, name: "Workshop Seat", price: 1999.00, quantity: 40, sold_count: 38, sales_start: 1.month.ago, sales_end: 2.weeks.from_now)

order1 = Order.create!(user: attendee1, event: music_fest, status: "confirmed", total_amount: 2998.00, confirmation_number: "EVN-A1B2C3D4")
OrderItem.create!(order: order1, ticket_tier: music_regular, quantity: 2, unit_price: 1499.00)
Payment.create!(order: order1, amount: 2998.00, status: "completed", provider_reference: "ch_abc123def456")

order2 = Order.create!(user: attendee2, event: tech_conf, status: "confirmed", total_amount: 4999.00, confirmation_number: "EVN-E5F6G7H8")
OrderItem.create!(order: order2, ticket_tier: conf_premium, quantity: 1, unit_price: 4999.00)
Payment.create!(order: order2, amount: 4999.00, status: "completed", provider_reference: "ch_xyz789ghi012")

order3 = Order.create!(user: attendee3, event: workshop, status: "pending", total_amount: 1999.00, confirmation_number: "EVN-I9J0K1L2")
OrderItem.create!(order: order3, ticket_tier: workshop_tier, quantity: 1, unit_price: 1999.00)
Payment.create!(order: order3, amount: 1999.00, status: "pending")

order4 = Order.create!(user: attendee1, event: tech_conf, status: "cancelled", total_amount: 2499.00, confirmation_number: "EVN-M3N4O5P6")
OrderItem.create!(order: order4, ticket_tier: conf_standard, quantity: 1, unit_price: 2499.00)
Payment.create!(order: order4, amount: 2499.00, status: "refunded")

puts "Seeded: #{User.count} users, #{Event.count} events, #{TicketTier.count} tiers, #{Order.count} orders"
