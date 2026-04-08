# EventNest — Event Ticketing Platform API

A Rails 7 API-only application for managing events, ticket sales, and orders.

## Quick Setup (Docker — Recommended)

```bash
# Clone and enter the repo
git clone <repo-url> && cd eventnest

# Start the app and database
docker-compose up --build

# In a separate terminal, set up the database
docker-compose exec web rails db:create db:migrate db:seed

# Run the test suite
docker-compose exec web bundle exec rspec

# The API is now running at http://localhost:3000
```

## Manual Setup (without Docker)

Requires: Ruby 3.2+, PostgreSQL 15+, Bundler

```bash
# Run the setup script (installs deps, sets up DB, configures git hooks)
chmod +x bin/setup
./bin/setup

# Or do it manually:
bundle install
git config core.hooksPath .git-hooks
rails db:create db:migrate db:seed
bundle exec rspec
rails server
```

## AI Tool Conversation Tracking

**This repository is configured to automatically capture your AI coding tool conversation history with each git commit.** This includes conversations from Claude Code, Cursor, Aider, Continue.dev, Cody, Cline, and Windsurf.

This is part of the Ajackus evaluation process. We evaluate how you collaborate with AI tools — your prompting strategy, how you break down problems, and how you review AI suggestions. The captured conversations help us understand your workflow.

**How it works:**
- A pre-commit git hook runs automatically before each commit
- It copies conversation files from AI tool directories (e.g., `.claude/`, `.cursor/`) into `.ai-conversations/`
- These files are staged and included in your commit
- You don't need to do anything — it happens automatically

**What's captured:** Only AI tool conversation logs stored in the project directory. No system files, browsing history, or anything outside this repository.

**If you prefer a tool that doesn't store local conversations** (like browser-based ChatGPT), the screen recording will capture your interactions instead. No additional action needed from you.

## Seed Data

The seed file creates:
- 2 organizers (priya@eventnest.dev, rahul@eventnest.dev)
- 3 attendees (ananya@example.com, vikram@example.com, sneha@example.com)
- 5 events (3 published upcoming, 1 draft, 1 past)
- Multiple ticket tiers per event (some sold out)
- 4 sample orders with payments

All user passwords are: `password123`

## Authentication

Register or login to get a JWT token:

```bash
# Login as an attendee
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ananya@example.com","password":"password123"}'

# Use the returned token
curl -H "Authorization: Bearer <token>" http://localhost:3000/api/v1/events
```

## API Endpoints

### Auth
- `POST /api/v1/auth/register` — Create account
- `POST /api/v1/auth/login` — Sign in, get JWT

### Events
- `GET /api/v1/events` — List published upcoming events (public)
- `GET /api/v1/events/:id` — Event details (public)
- `POST /api/v1/events` — Create event (authenticated)
- `PUT /api/v1/events/:id` — Update event (authenticated)
- `DELETE /api/v1/events/:id` — Delete event (authenticated)

### Ticket Tiers
- `GET /api/v1/events/:event_id/ticket_tiers` — List tiers (public)
- `POST /api/v1/events/:event_id/ticket_tiers` — Create tier (authenticated)
- `PUT /api/v1/events/:event_id/ticket_tiers/:id` — Update tier (authenticated)
- `DELETE /api/v1/events/:event_id/ticket_tiers/:id` — Delete tier (authenticated)

### Orders
- `GET /api/v1/orders` — List orders (authenticated)
- `GET /api/v1/orders/:id` — Order details (authenticated)
- `POST /api/v1/orders` — Create order (authenticated)
- `POST /api/v1/orders/:id/cancel` — Cancel order (authenticated)

## Tech Stack

- Ruby 3.2.2 / Rails 7.1
- PostgreSQL 15
- JWT authentication
- Sidekiq (background jobs)
- RSpec + FactoryBot (testing)
