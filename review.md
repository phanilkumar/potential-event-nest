# Security Review: SQL Injection

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
