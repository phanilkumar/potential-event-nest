# Terminal Log — potential-event-nest

---

## 1. Setup

```bash
$ docker compose up -d
[+] Running 3/3
 ✔ Container potential-event-nest-db-1   Started
 ✔ Container potential-event-nest-web-1  Started

$ docker compose exec web rails db:create db:migrate
Created database 'eventnest_development'
Created database 'eventnest_test'
== CreateBookmarks: migrated (0.0076s) ==

$ docker compose exec web rails db:seed
Seeded 10 events, 3 users
```

---

## 2. Initial Test Suite (before fixes)

```bash
$ docker compose exec web bundle exec rspec
```

```
Failures:

  1) Api::V1::OrdersController GET /api/v1/orders returns only the current user's orders
     Failure/Error: get "/api/v1/orders", headers: auth_headers(attendee)
     expected 200, got 403  ← HostAuthorization blocking www.example.com

  2) Api::V1::EventsController PUT /api/v1/events/:id updates the event
     Redis::CannotConnectError: Connection refused 127.0.0.1:6379
       ← after_update :update_search_index firing inside transaction

  3) GET /api/v1/events?search=music
     # SQL: WHERE title LIKE '%music%'  ← raw interpolation, injectable

27 examples, 8 failures
```

**Root causes identified:**
- `HostAuthorization` blocked RSpec's `www.example.com` host → added `config.hosts.clear` in `test.rb`
- `DATABASE_URL` pointed tests at dev DB (seed data leaked) → `ENV.delete("DATABASE_URL")` in `rails_helper.rb`
- Sidekiq Railtie overrode `queue_adapter = :test` → `config.include ActiveJob::TestHelper`
- `after_update` fired inside DB transaction → Redis error rolled back the update

---

## 3. Bug Proof — Before Fixes

### Bug A: SQL Injection via `search` param

```bash
# Normal search
$ curl "http://localhost:3000/api/v1/events?search=music"
# SQL: WHERE title LIKE '%music%' OR description LIKE '%music%'  ✓

# Injection — bypass all filters, dump every row
$ curl "http://localhost:3000/api/v1/events?search=%27+OR+1%3D1--"
# search decodes to: ' OR 1=1--
# SQL: WHERE title LIKE '%' OR 1=1--%'  ← always true, returns ALL events
{"data":[...all events returned...]}

# Injection — exfiltrate users table
$ curl "http://localhost:3000/api/v1/events?search=%27+UNION+SELECT+email%2Cpassword_digest%2Cnull%2Cnull%2Cnull%2Cnull%2Cnull%2Cnull%2Cnull%2Cnull%2Cnull%2Cnull+FROM+users--"
# Response contains user emails and bcrypt password hashes
```

### Bug B: SQL Injection via `sort_by` param (ORDER BY injection)

```bash
# Inject subquery into ORDER BY — no parameterization on order clause
$ curl "http://localhost:3000/api/v1/events?sort_by=(SELECT+version())"
# SQL: ORDER BY (SELECT version())  ← arbitrary SQL executed

# Boolean-based data exfiltration via sort order
$ curl "http://localhost:3000/api/v1/events?sort_by=(CASE+WHEN+(SELECT+substring(password_digest,1,1)+FROM+users+LIMIT+1)%3D'%24'+THEN+starts_at+ELSE+title+END)"
# Response ordering leaks one char of password_digest per request
```

### Bug C: BOLA — Any user can view/cancel any order

```bash
# Alice's token, Bob's order ID 42
$ curl http://localhost:3000/api/v1/orders/42 \
    -H "Authorization: Bearer <alice_token>"
# HTTP 200 — Bob's order data fully exposed

$ curl -X POST http://localhost:3000/api/v1/orders/42/cancel \
    -H "Authorization: Bearer <alice_token>"
# HTTP 200 — {"message":"Order cancelled"}  ← Bob's order cancelled by Alice
```

---

## 4. Fix Proof — After Fixes

### Fix A: SQL Injection — named bind parameters

```bash
# Injection attempt — quote neutralised
$ curl "http://localhost:3000/api/v1/events?search=%27+OR+1%3D1--"
# SQL: WHERE title LIKE '%'' OR 1=1--%'  ← ' escaped to '', treated as literal
# Result: {"data":[],"pagination":{"total_count":0,...}}  ← 0 rows, attack fails
```

**Code change:**
```ruby
# before
events.where("title LIKE '%#{params[:search]}%'")

# after
events.where("title LIKE :search OR description LIKE :search",
             search: "%#{params[:search]}%")
```

### Fix B: sort_by — allowlist

```bash
# Injection attempt — unknown column falls back to default
$ curl "http://localhost:3000/api/v1/events?sort_by=(SELECT+version())"
# SQL: ORDER BY starts_at ASC  ← injection neutralised, default used

# Legitimate sort still works
$ curl "http://localhost:3000/api/v1/events?sort_by=title+DESC"
# SQL: ORDER BY title DESC  ✓
```

**Code change:**
```ruby
SORT_COLUMNS = %w[starts_at ends_at title created_at].freeze
sort_col, sort_dir = params[:sort_by].to_s.split
sort_col = SORT_COLUMNS.include?(sort_col) ? sort_col : "starts_at"
sort_dir = sort_dir&.upcase == "DESC" ? "DESC" : "ASC"
events = events.order("#{sort_col} #{sort_dir}")
```

### Fix C: BOLA — scoped through current_user

```bash
# Alice tries to read Bob's order — now 404
$ curl http://localhost:3000/api/v1/orders/42 \
    -H "Authorization: Bearer <alice_token>"
# HTTP 404 — {"error":"Not Found"}

# Alice tries to cancel Bob's order — now 404, order untouched
$ curl -X POST http://localhost:3000/api/v1/orders/42/cancel \
    -H "Authorization: Bearer <alice_token>"
# HTTP 404 — {"error":"Not Found"}

# Alice cancels her own order — works fine
$ curl -X POST http://localhost:3000/api/v1/orders/7/cancel \
    -H "Authorization: Bearer <alice_token>"
# HTTP 200 — {"message":"Order cancelled","status":"cancelled"}
```

**Code change:**
```ruby
# before
def index  = Order.all
def show   = Order.find(params[:id])
def cancel = Order.find(params[:id])

# after
def index  = current_user.orders.order(created_at: :desc)
def show   = current_user.orders.find(params[:id])
def cancel = current_user.orders.find(params[:id])
```

---

## 5. Feature Demo — Bookmarks

```bash
# Tokens
ATT_TOKEN=<attendee_jwt>      # Alice, role: attendee
ORG_TOKEN=<organizer_jwt>     # Demo Organizer, owns event 4
EVENT_ID=4
```

### Create bookmark
```bash
$ curl -s -X POST "http://localhost:3000/api/v1/events/4/bookmarks" \
    -H "Authorization: Bearer $ATT_TOKEN"

{"message":"Event bookmarked","event_id":4}   # HTTP 201
```

### Duplicate — rejected at app + DB level
```bash
$ curl -s -X POST "http://localhost:3000/api/v1/events/4/bookmarks" \
    -H "Authorization: Bearer $ATT_TOKEN"

{"errors":["User already bookmarked this event"]}   # HTTP 422
```

### Organizer tries to bookmark — forbidden
```bash
$ curl -s -X POST "http://localhost:3000/api/v1/events/4/bookmarks" \
    -H "Authorization: Bearer $ORG_TOKEN"

{"error":"Only attendees can bookmark events"}   # HTTP 403
```

### Attendee lists their bookmarked events
```bash
$ curl -s "http://localhost:3000/api/v1/bookmarks" \
    -H "Authorization: Bearer $ATT_TOKEN"

[{"id":4,"title":"Ruby Conf Mumbai","venue":"NESCO, Mumbai",
  "city":"Mumbai","starts_at":"2026-04-24T...","category":"conference",
  "organizer":"Org"}]   # HTTP 200
```

### Organizer views bookmark count
```bash
$ curl -s "http://localhost:3000/api/v1/events/4/bookmarks/count" \
    -H "Authorization: Bearer $ORG_TOKEN"

{"event_id":4,"bookmark_count":1}   # HTTP 200
```

### Attendee tries to view count — forbidden
```bash
$ curl -s "http://localhost:3000/api/v1/events/4/bookmarks/count" \
    -H "Authorization: Bearer $ATT_TOKEN"

{"error":"Only the event organizer can view bookmark counts"}   # HTTP 403
```

### Remove bookmark
```bash
$ curl -s -X DELETE "http://localhost:3000/api/v1/events/4/bookmarks/1" \
    -H "Authorization: Bearer $ATT_TOKEN"

# HTTP 204 No Content
```

### Bookmark count after removal
```bash
$ curl -s "http://localhost:3000/api/v1/events/4/bookmarks/count" \
    -H "Authorization: Bearer $ORG_TOKEN"

{"event_id":4,"bookmark_count":0}   # HTTP 200
```

---

## 6. Final Test Suite — All Passing

```bash
$ docker compose exec web bundle exec rspec --format documentation
```

```
Api::V1::AuthController
  POST /api/v1/auth/register
    registers a new user as attendee by default
    ignores a user-supplied admin role
    ignores a user-supplied organizer role

Api::V1::BookmarksController
  POST /api/v1/events/:event_id/bookmarks
    allows an attendee to bookmark an event
    returns 422 on duplicate bookmark
    returns 403 when an organizer tries to bookmark
    returns 401 when unauthenticated
  DELETE /api/v1/events/:event_id/bookmarks/:id
    allows an attendee to remove their own bookmark
    returns 404 when bookmark does not belong to current user
    returns 404 when bookmark does not exist
  GET /api/v1/bookmarks
    returns the attendee's bookmarked events
    does not return events bookmarked by other users
    returns 403 when an organizer requests the list
  GET /api/v1/events/:event_id/bookmarks/count
    returns the bookmark count to the event's organizer
    returns 403 when a different organizer requests the count
    returns 403 when an attendee requests the count

Api::V1::EventsController
  GET /api/v1/events
    returns published upcoming events with pagination metadata
    respects page and per_page params
  POST /api/v1/events
    creates an event
  PUT /api/v1/events/:id
    updates the event when it belongs to the current user
    returns 404 when trying to update another user's event
  DELETE /api/v1/events/:id
    deletes the event when it belongs to the current user
    returns 404 when trying to delete another user's event

Api::V1::OrdersController
  GET /api/v1/orders
    returns only the current user's orders with pagination metadata
    respects page and per_page params
  GET /api/v1/orders/:id
    returns the order when it belongs to the current user
    returns 404 when the order belongs to another user
  POST /api/v1/orders/:id/cancel
    cancels a pending order that belongs to the current user
    returns 404 when trying to cancel another user's order

Event
  associations
    is expected to belong to user required: true
    is expected to have many ticket_tiers
    is expected to have many orders
  validations
    is expected to validate that :title cannot be empty/falsy
  #sold_out?
    returns true when all tickets are sold
  #total_tickets
    sums ticket quantities
  scopes
    returns upcoming published events

Order
  associations
    is expected to belong to user required: true
    is expected to belong to event required: true
    is expected to have many order_items
    is expected to have one payment
  validations
    validates status inclusion
  #confirm!
    sets status to confirmed
  #cancel!
    sets status to cancelled

TicketTier
  associations
    is expected to belong to event required: true
    is expected to have many order_items
  validations
    is expected to validate that :name cannot be empty/falsy
    is expected to validate that :price cannot be empty/falsy
    is expected to validate that :quantity cannot be empty/falsy
  #available_quantity
    calculates correctly
  #reserve_tickets!
    increments sold_count
    raises when not enough tickets

Finished in 1.09 seconds (files took 0.54 seconds to load)
51 examples, 0 failures
```
