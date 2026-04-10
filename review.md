#1) Security Review: SQL Injection

**File:** `app/controllers/api/v1/events_controller.rb`, line 10
**Severity:** Critical

## Vulnerable Code

```ruby
events.where("title LIKE '%#{params[:search]}%' OR description LIKE '%#{params[:search]}%'")
```

## How

`params[:search]` is interpolated directly into a raw SQL string. A user can pass `' OR 1=1--` to bypass filters, or `' UNION SELECT email, password_digest FROM users--` to exfiltrate data.

## Why

Ruby's `#{}` embeds user input into SQL text before the database sees it. The DB cannot tell data from SQL syntax.

## Fix

```ruby
events.where("title LIKE :search OR description LIKE :search", search: "%#{params[:search]}%")
```

Named bind parameters send the SQL template and value separately. The driver escapes the value, so quotes and SQL keywords inside it are inert.

---

## curl Demonstration

### Vulnerable (before fix)

**Normal call — works as intended:**
```bash
curl "http://localhost:3000/api/v1/events?search=music"
# SQL: WHERE title LIKE '%music%' OR description LIKE '%music%'
```

**Injection — bypass all filters, dump every event:**
```bash
curl "http://localhost:3000/api/v1/events?search=%27+OR+1%3D1--"
# search decodes to: ' OR 1=1--
# SQL: WHERE title LIKE '%' OR 1=1--%' OR description LIKE '...'
#                              ^^^^^^^^ always true, returns all rows
```

**Injection — exfiltrate users table:**
```bash
curl "http://localhost:3000/api/v1/events?search=%27+UNION+SELECT+email%2Cpassword_digest%2Cname%2Crole%2Cphone%2Cnull%2Cnull%2Cnull%2Cnull%2Cnull%2Cnull%2Cnull+FROM+users--"
# search decodes to: ' UNION SELECT email,password_digest,name,role,phone,null,... FROM users--
# SQL appends a second SELECT — response now contains user emails and password hashes
```

### Safe (after fix)

**Same injection attempt — neutralised:**
```bash
curl "http://localhost:3000/api/v1/events?search=%27+OR+1%3D1--"
# search decodes to: ' OR 1=1--
# SQL: WHERE title LIKE '%'' OR 1=1--%' OR description LIKE '%'' OR 1=1--%'
#                              ^^ quote is escaped to '' — treated as literal character, not SQL
# Result: no rows matched, attack fails
```

The single quote `'` becomes `''` (escaped), so it never closes the string literal and cannot inject SQL keywords.

---

#2) Security Review: Broken Object Level Authorization (BOLA)

**File:** `app/controllers/api/v1/orders_controller.rb`
**Severity:** Critical
**Type:** BOLA / IDOR (OWASP API Security #1)

## Vulnerable Code

```ruby
def index  = Order.all                  # returns every user's orders
def show   = Order.find(params[:id])    # any order ID works
def cancel = Order.find(params[:id])    # any order ID works
```

## How

All three actions fetch orders from the global scope with no check that the order belongs to the requesting user. Any authenticated user can enumerate, read, or cancel another user's orders by simply changing the ID in the request.

## curl — Vulnerable (before fix)

```bash
# Alice is logged in. Bob's order ID is 42.

# Alice reads Bob's order — succeeds, returns Bob's data
curl http://localhost:3000/api/v1/orders/42 \
  -H "Authorization: Bearer <alice_token>"

# Alice cancels Bob's order — succeeds
curl -X POST http://localhost:3000/api/v1/orders/42/cancel \
  -H "Authorization: Bearer <alice_token>"

# Alice dumps all orders from all users
curl http://localhost:3000/api/v1/orders \
  -H "Authorization: Bearer <alice_token>"
```

## Fix

Scope every lookup through `current_user.orders` instead of the global `Order` scope. `find` on a scoped relation raises `ActiveRecord::RecordNotFound` (→ 404) when the record doesn't belong to the user.

```ruby
def index  = current_user.orders.order(created_at: :desc)
def show   = current_user.orders.find(params[:id])
def cancel = current_user.orders.find(params[:id])
```

## curl — Vulnerable (before fix)

> Alice is authenticated. Bob's order ID is 42.

```bash
# Alice lists ALL orders from every user — 200, full dump
curl http://localhost:3000/api/v1/orders \
  -H "Authorization: Bearer <alice_token>"
# response: [{id: 1, ...}, {id: 42, ...}, {id: 99, ...}]  ← Bob's and everyone else's orders included

# Alice reads Bob's order — 200, Bob's data exposed
curl http://localhost:3000/api/v1/orders/42 \
  -H "Authorization: Bearer <alice_token>"
# response: {id: 42, confirmation_number: "EVN-...", total_amount: 1500.0, ...}

# Alice cancels Bob's order — 200, order cancelled
curl -X POST http://localhost:3000/api/v1/orders/42/cancel \
  -H "Authorization: Bearer <alice_token>"
# response: {message: "Order cancelled", status: "cancelled"}
```

## curl — Safe (after fix)

```bash
# Alice lists orders — 200, only her own orders returned
curl http://localhost:3000/api/v1/orders \
  -H "Authorization: Bearer <alice_token>"
# response: [{id: 7, ...}, {id: 23, ...}]  ← only Alice's orders

# Alice tries to read Bob's order 42 — 404, not found
curl http://localhost:3000/api/v1/orders/42 \
  -H "Authorization: Bearer <alice_token>"
# response: {error: "Not Found"}

# Alice tries to cancel Bob's order 42 — 404, not found, Bob's order untouched
curl -X POST http://localhost:3000/api/v1/orders/42/cancel \
  -H "Authorization: Bearer <alice_token>"
# response: {error: "Not Found"}

# Alice cancels her own order 7 — 200, works fine
curl -X POST http://localhost:3000/api/v1/orders/7/cancel \
  -H "Authorization: Bearer <alice_token>"
# response: {message: "Order cancelled", status: "cancelled"}
```

---

#3) Security Review: BOLA on Events (update & delete)

**File:** `app/controllers/api/v1/events_controller.rb`
**Severity:** Critical
**Type:** BOLA / IDOR (OWASP API Security #1)

## Vulnerable Code

```ruby
def update  = Event.find(params[:id])   # any event ID — no ownership check
def destroy = Event.find(params[:id])   # any event ID — no ownership check
```

## How

Any authenticated user can update or delete any event by supplying its ID. No check that the event belongs to `current_user`.

## curl — Before fix

```bash
# Bob updates Alice's event 107 — 200, title changed
curl -s -X PUT http://localhost:3000/api/v1/events/107 \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -d '{"event":{"title":"Hacked by Bob"}}'
# response: {"title":"Hacked by Bob", "organizer":{"name":"Alice"}, ...}

# Bob deletes Alice's event — 204, gone permanently
curl -s -X DELETE http://localhost:3000/api/v1/events/107 \
  -H "Authorization: Bearer $BOB_TOKEN"
# HTTP Status: 204
```

## Fix

```ruby
def update  = current_user.events.find(params[:id])
def destroy = current_user.events.find(params[:id])
```

## curl — After fix

```bash
# Bob tries to update Alice's event — 404
curl -s -X PUT http://localhost:3000/api/v1/events/107 \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -d '{"event":{"title":"Hacked by Bob"}}'
# response: {"error":"Not Found"}

# Bob tries to delete Alice's event — 404, event untouched
curl -s -X DELETE http://localhost:3000/api/v1/events/107 \
  -H "Authorization: Bearer $BOB_TOKEN"
# HTTP Status: 404

# Alice updates her own event — 200
curl -s -X PUT http://localhost:3000/api/v1/events/107 \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{"event":{"title":"Alice Workshop Updated"}}'
# response: {"title":"Alice Workshop Updated", ...}

# Alice deletes her own event — 204
curl -s -X DELETE http://localhost:3000/api/v1/events/107 \
  -H "Authorization: Bearer $ALICE_TOKEN"
# HTTP Status: 204
```

## Bonus fix — `app/models/event.rb`

```ruby
# before — job fires inside DB transaction; Redis error rolls back the update
after_update  :update_search_index

# after — job fires after commit; failure never affects the DB write
after_commit  :update_search_index, on: :update
```

---

#4) Security Review: Mass Assignment — sold_count exposed

**File:** `app/controllers/api/v1/ticket_tiers_controller.rb`, line 53
**Severity:** High
**Type:** Mass Assignment / Business Logic Bypass

## Vulnerable Code

```ruby
params.require(:ticket_tier).permit(:name, :price, :quantity, :sold_count, :sales_start, :sales_end)
```

## How

`sold_count` is the system-managed counter of how many tickets have been sold. Permitting it means any authenticated user can set it to any value — zeroing it to make a sold-out tier appear available again, or inflating it to block others from buying.

## curl — Before fix

```bash
# Reset sold_count to 0 on a sold-out tier — makes it appear fully available
curl -s -X PUT http://localhost:3000/api/v1/events/1/ticket_tiers/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"ticket_tier": {"sold_count": 0}}'
# sold_count is now 0 — tier appears available despite tickets already sold
```

## Fix

```ruby
params.require(:ticket_tier).permit(:name, :price, :quantity, :sales_start, :sales_end)
```

`sold_count` removed from permitted params. It is only ever updated internally by `reserve_tickets!` when an order is placed — never from user input.

## curl — After fix

```bash
# Same request — sold_count param is silently ignored
curl -s -X PUT http://localhost:3000/api/v1/events/1/ticket_tiers/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"ticket_tier": {"sold_count": 0}}'
# sold_count unchanged in DB — business logic intact
```

---

#5) Bug Fix: Race Condition in Ticket Reservation

**File:** `app/models/ticket_tier.rb`
**Severity:** High
**Type:** Race Condition / TOCTOU (Time-of-Check to Time-of-Use)

## Vulnerable Code

```ruby
def reserve_tickets!(count)
  if available_quantity >= count   # 1. check
    self.sold_count += count       # 2. modify in memory
    save!                          # 3. write back
  else
    raise "Not enough tickets available"
  end
end
```

## How

Two concurrent requests both read `available_quantity` before either writes back. Both pass the check, both increment from the same stale baseline, and the last write overwrites the first — resulting in oversold tickets.

```
Thread A reads available_quantity → 2  ✓ passes
Thread B reads available_quantity → 2  ✓ passes  (before A writes)
Thread A: sold_count += 2 → save!  →  DB: sold_count = 2
Thread B: sold_count += 2 → save!  →  DB: sold_count = 2  ← A's write lost
Result: 4 tickets sold against 2 available
```

## Fix

```ruby
def reserve_tickets!(count)
  with_lock do
    raise "Not enough tickets available" if available_quantity < count
    increment!(:sold_count, count)
  end
end
```

## Why this works

`with_lock` issues `SELECT ... FOR UPDATE` — a pessimistic row-level lock. PostgreSQL blocks any other transaction from reading or writing that row until the lock is released. The check and the increment are now a single atomic unit.

```
Thread A: SELECT FOR UPDATE → acquires lock
Thread B: SELECT FOR UPDATE → blocks, waits
Thread A: available_quantity → 2 ✓, increment! sold_count = 2, commit → releases lock
Thread B: lock acquired → available_quantity → 0 ✗ → raises "Not enough tickets available"
Result: exactly 2 tickets sold — no oversell
```

`increment!` issues a single `UPDATE sold_count = sold_count + N` — no stale in-memory value involved.

---

#6) Bug Fix: N+1 Queries in Events Controller

**File:** `app/controllers/api/v1/events_controller.rb`
**Severity:** Medium
**Type:** Performance / N+1 Query

## Vulnerable Code

```ruby
# index
events = Event.published.upcoming
# map loop fires per-event:
event.user.name        # SELECT * FROM users WHERE id = ?  ×N
event.ticket_tiers.map # SELECT * FROM ticket_tiers WHERE event_id = ?  ×N

# show
event = Event.find(params[:id])
event.user             # separate query
event.ticket_tiers     # separate query
```

## How

For 50 events, `index` executes 1 (events) + 50 (users) + 50 (ticket_tiers) = **101 queries**. Rails loads each association lazily on first access inside the loop.

## Fix

```ruby
# index
events = Event.published.upcoming.includes(:user, :ticket_tiers)

# show
event = Event.includes(:user, :ticket_tiers).find(params[:id])
```

`includes` issues two bulk `IN` queries after the primary fetch — associations are pre-loaded in memory, so the loop touches no DB at all.

## Query count

| | Before | After |
|---|---|---|
| `index` (50 events) | 101 queries | 3 queries |
| `show` | 3 queries | 1 query |

---

#7) Security Review: SQL Injection via `sort_by` Parameter

**File:** `app/controllers/api/v1/events_controller.rb`, line 21
**Severity:** Critical
**Type:** SQL Injection (Order-by clause)

## Vulnerable Code

```ruby
events = events.order(params[:sort_by] || "starts_at ASC")
```

## How

`params[:sort_by]` is passed raw into `.order()`. Unlike `WHERE` clauses, Rails does **not** parameterize `ORDER BY` — the string goes straight into SQL.

```bash
# Dump DB version — blind injection via order clause
curl "http://localhost:3000/api/v1/events?sort_by=(SELECT+version())"

# Boolean-based data exfiltration
curl "http://localhost:3000/api/v1/events?sort_by=(CASE+WHEN+(SELECT+substring(password_digest,1,1)+FROM+users+LIMIT+1)='$'+THEN+starts_at+ELSE+title+END)"
```

## Fix

```ruby
SORT_COLUMNS = %w[starts_at ends_at title created_at].freeze
sort_col, sort_dir = params[:sort_by].to_s.split
sort_col = SORT_COLUMNS.include?(sort_col) ? sort_col : "starts_at"
sort_dir = sort_dir&.upcase == "DESC" ? "DESC" : "ASC"
events = events.order("#{sort_col} #{sort_dir}")
```

Only allowlisted column names pass through. Direction is forced to `ASC` or `DESC`. No user input ever touches the raw SQL string.

## curl — Before fix

```bash
# Inject subquery into ORDER BY — returns DB version in sort behaviour
curl "http://localhost:3000/api/v1/events?sort_by=(SELECT+version())"
# SQL: ORDER BY (SELECT version())  ← arbitrary SQL executed
```

## curl — After fix

```bash
# Injection attempt — unknown column falls back to default
curl "http://localhost:3000/api/v1/events?sort_by=(SELECT+version())"
# sort_col not in allowlist → defaults to "starts_at ASC"
# SQL: ORDER BY starts_at ASC  ← injection neutralised

# Legitimate use still works
curl "http://localhost:3000/api/v1/events?sort_by=title+DESC"
# SQL: ORDER BY title DESC
```

---

#8) Bug Fix: Blocking I/O in `geocode_venue` before save

**File:** `app/models/event.rb`, `app/jobs/geocode_venue_job.rb` (new)
**Severity:** High
**Type:** Blocking I/O / Performance

## Vulnerable Code

```ruby
before_save :geocode_venue

def geocode_venue
  if venue.present?
    Rails.logger.info("Geocoding venue: #{venue}")
    sleep(0.1)                              # external HTTP call — blocks web thread
    self.city = venue.split(",").last&.strip
  end
end
```

## Problems

1. **Blocks the DB transaction** — `before_save` runs inside the open transaction. Every external API call holds the transaction open and ties up a DB connection.
2. **Fires on every save** — a status update, a title change, anything — triggers a geocoding HTTP call even when `venue` didn't change.

## Fix

Move the HTTP call into a background job and only enqueue it when `venue` actually changed.

**`app/models/event.rb`**
```ruby
# removed: before_save :geocode_venue
after_commit :enqueue_geocode_if_venue_changed, on: [:create, :update]

def enqueue_geocode_if_venue_changed
  GeocodeVenueJob.perform_later(id) if saved_change_to_venue?
end
```

**`app/jobs/geocode_venue_job.rb`** (new)
```ruby
class GeocodeVenueJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event&.venue.present?

    city = event.venue.split(",").last&.strip
    event.update_column(:city, city) if city.present?
  end
end
```

## Why this works

| | Before | After |
|---|---|---|
| DB transaction held open | Yes — during HTTP call | No — job fires after commit |
| Fires when venue unchanged | Yes — every save | No — guarded by `saved_change_to_venue?` |
| Web thread blocked | Yes | No — Sidekiq worker handles it |

`after_commit` fires after the transaction is fully committed so no DB connection is held. `saved_change_to_venue?` ensures the job is only enqueued when the venue field actually changed. `update_column` in the job bypasses callbacks to avoid re-enqueuing.

---

#9) Security Review: Mass Assignment — Role Escalation on Registration

**File:** `app/controllers/api/v1/auth_controller.rb`
**Severity:** Critical
**Type:** Mass Assignment / Privilege Escalation

## Vulnerable Code

```ruby
def register_params
  params.permit(:name, :email, :password, :password_confirmation, :role, :phone)
end
```

## How

`:role` is in the permitted list. Any unauthenticated user can self-assign `admin` or `organizer` during signup and gain full elevated privileges immediately.

## curl — Before fix

```bash
# Register as admin — succeeds, gets admin token
curl -s -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Eve","email":"eve@evil.com","password":"password123","password_confirmation":"password123","role":"admin"}'
# response: {"token":"...","user":{"role":"admin"}}  ← admin account created
```

## Fix

```ruby
# remove :role from permit
def register_params
  params.permit(:name, :email, :password, :password_confirmation, :phone)
end

# force attendee regardless of what was sent
def register
  user = User.new(register_params)
  user.role = "attendee"  # never trust user-supplied role
  ...
end
```

Two-layer defence: `role` is not permitted (stripped by strong parameters) **and** explicitly overwritten to `"attendee"` before save. Role elevation must go through a separate privileged admin endpoint.

## curl — After fix

```bash
# Same request — role param silently ignored, account created as attendee
curl -s -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Eve","email":"eve@evil.com","password":"password123","password_confirmation":"password123","role":"admin"}'
# response: {"token":"...","user":{"role":"attendee"}}  ← always attendee
```
