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
