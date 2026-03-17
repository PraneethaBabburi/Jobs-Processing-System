# cURL Examples — Distributed Job Processing System

Use these against the **REST API**.

- **Local (API on host):** `http://localhost:8080`
- **Docker Compose (demo stack):** `http://localhost:8083`

---

## Jobs API

### Submit a job (POST /jobs)

**Hello job (minimal) — local:**
```bash
curl -s -X POST http://localhost:8080/jobs \
  -H "Content-Type: application/json" \
  -d '{"type":"hello","payload":"world"}'
```
**Hello job (minimal) — Docker Compose:**
```bash
curl -s -X POST http://localhost:8083/jobs \
  -H "Content-Type: application/json" \
  -d '{"type":"hello","payload":"world"}'
```
Example response: `{"job_id":"<uuid>"}`

**Email job — local:**
```bash
curl -s -X POST http://localhost:8080/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "email",
    "payload": {
      "to": "user@example.com",
      "subject": "Welcome",
      "body": "Hello from the job queue."
    }
  }'
```

**Email job — Docker Compose:**
```bash
curl -s -X POST http://localhost:8083/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "email",
    "payload": {
      "to": "user@example.com",
      "subject": "Welcome",
      "body": "Hello from the job queue."
    }
  }'
```

**Report job (CSV) — local:**
```bash
curl -s -X POST http://localhost:8080/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "report",
    "payload": {
      "headers": ["Name", "Count"],
      "rows": [["A", "1"], ["B", "2"]],
      "out_path": "/out/demo-report.csv"
    }
  }'
```

**Report job (CSV) — Docker Compose:**
```bash
curl -s -X POST http://localhost:8083/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "report",
    "payload": {
      "headers": ["Name", "Count"],
      "rows": [["A", "1"], ["B", "2"]],
      "out_path": "/out/demo-report.csv"
    }
  }'
```

**Invoice job — local:**
```bash
curl -s -X POST http://localhost:8080/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "invoice",
    "payload": {
      "template": "Invoice #{{.ID}}\nTotal: {{.Total}}",
      "data": {"ID": "INV-001", "Total": "99.00"},
      "out_path": "/out/invoice-001.txt"
    }
  }'
```

**Invoice job — Docker Compose:**
```bash
curl -s -X POST http://localhost:8083/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "invoice",
    "payload": {
      "template": "Invoice #{{.ID}}\nTotal: {{.Total}}",
      "data": {"ID": "INV-001", "Total": "99.00"},
      "out_path": "/out/invoice-001.txt"
    }
  }'
```

**With options (queue, retries, delay) — local:**
```bash
# High-priority queue
curl -s -X POST http://localhost:8080/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "email",
    "payload": {"to":"a@b.com","subject":"Hi","body":""},
    "options": {"queue": "high", "max_retry": 3}
  }'

# Delayed (run at Unix timestamp; e.g. 60 seconds from now)
RUN_AT=$(($(date +%s) + 60))
curl -s -X POST http://localhost:8080/jobs \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"hello\",\"payload\":\"later\",\"options\":{\"run_at_unix_sec\":$RUN_AT}}"
```

**With options (queue, retries, delay) — Docker Compose:**
```bash
# High-priority queue
curl -s -X POST http://localhost:8083/jobs \
  -H "Content-Type: application/json" \
  -d '{
    "type": "email",
    "payload": {"to":"a@b.com","subject":"Hi","body":""},
    "options": {"queue": "high", "max_retry": 3}
  }'

# Delayed (run at Unix timestamp; e.g. 60 seconds from now)
RUN_AT=$(($(date +%s) + 60))
curl -s -X POST http://localhost:8083/jobs \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"hello\",\"payload\":\"later\",\"options\":{\"run_at_unix_sec\":$RUN_AT}}"
```

---

### Get job status (GET /jobs/{id})

```bash
JOB_ID="<paste-job-id-from-submit-response>"
curl -s http://localhost:8080/jobs/$JOB_ID    # local
curl -s http://localhost:8083/jobs/$JOB_ID    # Docker Compose
```
Example response: `{"job_id":"...","status":"completed","attempt":0,"last_error":""}`

---

### List jobs (GET /jobs)

**All jobs (default limit 100):**
```bash
curl -s "http://localhost:8080/jobs"   # local
curl -s "http://localhost:8083/jobs"   # Docker Compose
```

**With query params (queue, status, limit, offset):**
```bash
curl -s "http://localhost:8080/jobs?queue=default&status=pending&limit=20&offset=0"   # local
curl -s "http://localhost:8083/jobs?queue=default&status=pending&limit=20&offset=0"   # Docker Compose
```

Requires **Postgres** (`POSTGRES_DSN` set); otherwise returns an empty list.

---

### Retry archived job (POST /jobs/{id}/retry)

For jobs that ended up in the dead-letter queue (DLQ).

```bash
JOB_ID="<archived-job-id>"
curl -s -X POST http://localhost:8080/jobs/$JOB_ID/retry \
  -H "Content-Type: application/json" \
  -d '{"queue":"default"}'

curl -s -X POST http://localhost:8083/jobs/$JOB_ID/retry \
  -H "Content-Type: application/json" \
  -d '{"queue":"default"}'
```
Example response: `{"ok":"true","job_id":"<new-job-uuid>"}` — use `job_id` to check status of the replayed job.

---

### Cancel job (POST /jobs/{id}/cancel)

Cancels a pending or scheduled job. Returns 409 if the job is already running or completed.

```bash
JOB_ID="<job-id>"
curl -s -X POST http://localhost:8080/jobs/$JOB_ID/cancel \
  -H "Content-Type: application/json" \
  -d '{}'

curl -s -X POST http://localhost:8083/jobs/$JOB_ID/cancel \
  -H "Content-Type: application/json" \
  -d '{}'
```
Optional body: `{"queue":"default"}` if you know the queue.

---

## Admin API

### List queues (GET /admin/queues)

```bash
curl -s http://localhost:8080/admin/queues   # local
curl -s http://localhost:8083/admin/queues   # Docker Compose
```
Example response: `{"queues":[{"name":"high","pending":0,"active":0,"scheduled":0,"retry":0,"archived":0,"paused":false},...]}`

---

### Pause queue (POST /admin/queues/{name}/pause)

```bash
curl -s -X POST http://localhost:8080/admin/queues/default/pause   # local
curl -s -X POST http://localhost:8083/admin/queues/default/pause   # Docker Compose
```
Example response: `{"ok":"true"}`

---

### Unpause queue (POST /admin/queues/{name}/unpause)

```bash
curl -s -X POST http://localhost:8080/admin/queues/default/unpause   # local
curl -s -X POST http://localhost:8083/admin/queues/default/unpause   # Docker Compose
```

---

## Upstream demo services

These services call the Job API internally; you trigger jobs by calling the upstream HTTP API.

### User service (port 8081)

**Register (sends welcome email job):**
```bash
curl -s -X POST http://localhost:8081/register \
  -H "Content-Type: application/json" \
  -d '{"email":"newuser@example.com"}'
```

**Password reset (sends password reset email job):**
```bash
curl -s -X POST http://localhost:8081/password-reset \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'
```

---

### Billing service (port 8082)

**Create invoice job:**
```bash
curl -s -X POST http://localhost:8082/invoice \
  -H "Content-Type: application/json" \
  -d '{"id":"INV-002","total":"150.00"}'
```

**Generate report job:**
```bash
curl -s -X POST http://localhost:8082/report
```

**Send “invoice ready” email job:**
```bash
curl -s -X POST http://localhost:8082/invoice-ready \
  -H "Content-Type: application/json" \
  -d '{"email":"billing@example.com"}'
```

---

## One-liner flow (submit → status)

```bash
RESP=$(curl -s -X POST http://localhost:8080/jobs -H "Content-Type: application/json" -d '{"type":"hello","payload":"world"}')   # local
# RESP=$(curl -s -X POST http://localhost:8083/jobs -H "Content-Type: application/json" -d '{"type":"hello","payload":"world"}') # Docker Compose
JOB_ID=$(echo "$RESP" | jq -r '.job_id')
echo "Job ID: $JOB_ID"
sleep 2
curl -s http://localhost:8080/jobs/$JOB_ID | jq .   # local
# curl -s http://localhost:8083/jobs/$JOB_ID | jq . # Docker Compose
```

(Requires `jq`; without it, use `grep -o '"job_id":"[^"]*"'` and strip the quotes.)
