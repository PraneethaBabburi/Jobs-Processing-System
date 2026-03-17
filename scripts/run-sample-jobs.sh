#!/usr/bin/env bash
# Submits hello, email, and report jobs to the Job API (REST).
# Prerequisites: stack running (e.g. docker compose -f deploy/stack/docker-compose.yml up -d)
#                API REST on JOB_API_URL (default http://localhost:8083)

set -e
API="${JOB_API_URL:-http://localhost:8083}"
mkdir -p out 2>/dev/null || true

echo "=== Job Queue sample jobs ==="
echo "API: $API"
echo ""

max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -sf -o /dev/null --connect-timeout 2 "$API/jobs"; then
    break
  fi
  attempt=$((attempt + 1))
  if [ $attempt -eq $max_attempts ]; then
    echo "Error: API at $API not reachable after 60s."
    echo "  Ensure the stack is up: docker compose -f deploy/stack/docker-compose.yml up -d"
    echo "  Check job-api logs: docker compose -f deploy/stack/docker-compose.yml logs job-api"
    echo "  On Docker Desktop (Windows): try JOB_API_URL=http://127.0.0.1:8083"
    exit 1
  fi
  echo "Waiting for API... ($attempt/$max_attempts)"
  sleep 2
done

echo "Submitting jobs..."
echo ""

HELLO_RESP=$(curl -sf -X POST "$API/jobs" -H "Content-Type: application/json" -d '{"type":"hello","payload":"world"}')
HELLO_ID=$(echo "$HELLO_RESP" | grep -oE '"job_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | grep -oE '"[^"]*"$' | tr -d '"')
echo "1. Hello job   -> job_id: $HELLO_ID"

EMAIL_JSON='{"to":"sample@localhost","subject":"Sample Email","body":"Hello from the job queue! This was sent by the worker via MailHog."}'
EMAIL_RESP=$(curl -sf -X POST "$API/jobs" -H "Content-Type: application/json" -d "{\"type\":\"email\",\"payload\":$EMAIL_JSON}")
EMAIL_ID=$(echo "$EMAIL_RESP" | grep -oE '"job_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | grep -oE '"[^"]*"$' | tr -d '"')
echo "2. Email job   -> job_id: $EMAIL_ID"

REPORT_JSON='{"headers":["Name","Count"],"rows":[["Hello","1"],["World","2"],["Job Queue","3"]],"out_path":"/out/sample-report.csv"}'
REPORT_RESP=$(curl -sf -X POST "$API/jobs" -H "Content-Type: application/json" -d "{\"type\":\"report\",\"payload\":$REPORT_JSON}")
REPORT_ID=$(echo "$REPORT_RESP" | grep -oE '"job_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | grep -oE '"[^"]*"$' | tr -d '"')
echo "3. Report job  -> job_id: $REPORT_ID"

echo ""
echo "=== Where to see results ==="
echo "  Emails:    http://localhost:8025  (MailHog)"
echo "  Report:    ./out/sample-report.csv (after worker runs)"
echo "  Dashboard: http://localhost:8080"
echo ""
echo "Check status of a job:"
echo "  curl -s $API/jobs/$HELLO_ID"
echo ""
