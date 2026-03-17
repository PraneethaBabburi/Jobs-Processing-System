# Distributed Job Processing System — Project Summary

## 1. Project Overview

This is a **distributed job processing system** built in Go for local development and demo (Docker Compose, Kubernetes). It uses **Kafka** as the job queue (topics `job.requests` and `job.events`) and **PostgreSQL** for job metadata and status.

**Purpose:** Accept job submissions via a **REST API**, persist them in Postgres, enqueue them on Kafka, and process them asynchronously with workers. Supports multiple job types (hello, email, image resize, invoice, report), retries, delayed/scheduled jobs, and observability (Prometheus metrics, structured logging, health probes, tracing).

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CLIENTS / USERS                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│  grpcurl / enqueue CLI          Demo Dashboard (HTTP)         External Services  │
│  (SubmitJob, GetStatus)         (Submit + Status UI)          (gRPC clients)     │
└────────────────────────────┬───────────────────────┬────────────────────────────┘
                              │                       │
                              ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           JOB API (cmd/api)                                       │
│  • REST server (:8080) — submit jobs, get status, list jobs, cancel/retry, admin │
│  • HTTP metrics (:9090) — /metrics (Prometheus)                                   │
│  • Writes job rows to Postgres and enqueues messages to Kafka                    │
└────────────────────────────┬─────────────────────────────────────────────────────┘
                              │
                              │  Enqueue tasks (type + payload + options)
                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           KAFKA + POSTGRES                                       │
│  • Kafka topic `job.requests` for queued jobs                                     │
│  • Postgres tables: jobs, queues, schedules, archived (DLQ)                       │
└────────────────────────────┬─────────────────────────────────────────────────────┘
                              │
                              │  Poll & claim tasks
                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        JOB WORKER(S) (cmd/worker)                                 │
│  • Kafka consumer(s) from `job.requests`                                          │
│  • Dispatch by type → Registry → Handler (hello, email, image, etc.)             │
│  • HTTP :9090 — /health, /ready, /metrics                                         │
└────────────────────────────┬─────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────────┐
│ Hello        │    │ Email        │    │ Report / Invoice  │
│ (log only)   │    │ (SMTP e.g.   │    │ (CSV / template   │
│              │    │  MailHog)    │    │  → file)          │
└──────────────┘    └──────────────┘    └──────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────────┐
│ Image        │    │ (optional)   │    │ Observability     │
│ (resize,     │    │ MailHog UI   │    │ Prometheus, slog  │
│  thumbnail)  │    │ :8025        │    │ health probes     │
└──────────────┘    └──────────────┘    └──────────────────┘
```

### Data flow (high level)

1. **Submit:** Client → REST API → API writes job row to Postgres and enqueues to Kafka (`job.requests`).
2. **Process:** Worker consumes from Kafka → Registry lookup by type → Handler runs → success/failure (retry or archive) and status update in Postgres.
3. **Status:** Client → REST `GET /jobs/<id>` → API reads from Postgres → returns state (pending/processing/completed/failed/archived).
4. **DLQ:** Failed jobs (after max retries) go to archive; ListArchivedJobs / RetryArchivedJob operate on them.

---

## 3. Component Reference

| Component | Location | Role |
|-----------|----------|------|
| **Job API** | `cmd/api` | REST server for submit/status/list/cancel/retry/admin; HTTP /metrics; writes to Postgres and produces to Kafka. |
| **Worker** | `cmd/worker` | Kafka consumer; registers all job handlers, runs dispatcher; exposes /health, /ready, /metrics. |
| **Job registry** | `internal/jobs/registry.go` | Map of job type string → Handler; Register/Get/Types. |
| **Job registry** | `internal/jobs/registry.go` | Map of job type string → Handler; Register/Get/Types. |
| **Job handlers** | `internal/jobs/*.go` | hello, email, image, invoice, report; each implements Handler (Type, Handle). |
| **gRPC service impl** | `internal/api/server.go` | JobServer: enqueue with options (queue, max_retry, run_at), status via Inspector, list/retry archived. |
| **Metrics** | `internal/metrics/metrics.go` | Prometheus: jobs_enqueued_total, jobs_processed_total, job_processing_duration_seconds. |
| **Proto / gRPC** | `api/proto/` | job_service.proto and generated Go; defines API contract. |
| **Enqueue CLI** | `cmd/enqueue` | Small CLI to enqueue one job (e.g. `go run ./cmd/enqueue hello "world"`). |
| **Dashboard** | `cmd/dashboard` | HTTP dashboard (submit job, get status); proxies to Job API REST. |
| **Scheduler** | `cmd/scheduler` | Fake job scheduler; periodically writes jobs to Postgres and enqueues to Kafka. |
| **Deploy (stack)** | `deploy/stack/` | Docker Compose: Kafka, Postgres, MailHog, job-api, job-worker, scheduler, dashboard, Loki, Grafana, Jaeger. |
| **Deploy (Kubernetes)** | `deploy/kubernetes/` | K8s manifests: job-api, job-worker, job-scheduler, ConfigMap/Secret for Kafka and Postgres. |
| **Sample jobs script** | `scripts/run-sample-jobs.sh` | Submits hello, email, report jobs via REST; prints job IDs and links. |

---

## 4. Job Types and Handlers

| Type | Handler | Payload (JSON) | Behavior |
|------|---------|----------------|----------|
| **hello** | `jobs.Hello` | Any (e.g. `"world"`) | Logs payload and succeeds. |
| **email** | `jobs.Email` | `to`, `subject`, `body` | Sends via SMTP (e.g. MailHog in dev). |
| **image** | `jobs.Image` | `source_url` or `source_path`, `width`, `height`, optional `out_path` | Fetches/loads image, resizes (thumbnail), writes PNG to path. |
| **invoice** | `jobs.Invoice` | `template` (Go template), `data`, optional `out_path` | Renders template with data, writes to file. |
| **report** | `jobs.Report` | `headers`, `rows`, optional `out_path` | Writes CSV to file. |

Handlers use optional `*OutputDir` (e.g. `REPORT_OUTPUT_DIR`, `INVOICE_OUTPUT_DIR`, `IMAGE_OUTPUT_DIR`) so relative `out_path` is under that directory.

---

## 5. Real-Time Scenario Usage

### Scenario A: Quick local run (no Docker)

1. Start Postgres and Kafka (e.g. via Docker as in `README.md`).
2. Run API and worker on host:
   ```bash
   export POSTGRES_DSN=postgres://jobs:jobs@localhost:5432/jobs?sslmode=disable
   export KAFKA_BROKERS=localhost:9092
   go run ./cmd/api &
   go run ./cmd/worker &
   ```
3. Enqueue a hello job:
   ```bash
   go run ./cmd/enqueue hello "world"
   ```
4. Submit via gRPC and check status (grpcurl):
   ```bash
   grpcurl -plaintext -d '{"type":"hello","payload":"<base64>"}' localhost:50051 job.v1.JobService/SubmitJob
   grpcurl -plaintext -d '{"job_id":"<id>"}' localhost:50051 job.v1.JobService/GetJobStatus
   ```

**Real-time use:** Validation that jobs flow API → Kafka → worker and status is visible via Postgres.

---

### Scenario B: Full demo stack (Docker Compose)

1. Start stack:
   ```bash
   docker compose -f deploy/stack/docker-compose.yml up -d
   ```
2. Run demo script (submits hello, email, report):
   ```bash
   ./scripts/run-sample-jobs.sh
   ```
3. **Real-time checks:**
   - **Dashboard:** http://localhost:8080 — submit jobs (hello, email, report), paste job ID, get status.
   - **MailHog:** http://localhost:8026 — see email sent by the email job.
   - **Report:** `./out/demo-report.csv` — created after report job runs (worker writes to `/out` in container, bind-mounted to host).

**Real-time use:** End-to-end: submit from UI or script → worker processes → see email in MailHog and CSV on disk; status via dashboard or gRPC.

---

### Scenario C: Priority and delayed jobs

1. **High-priority email** (queue `high`):
   ```bash
   grpcurl -plaintext -d '{"type":"email","payload":"<base64>","options":{"queue":"high"}}' localhost:50051 job.v1.JobService/SubmitJob
   ```
2. **Delayed job** (run at Unix time):
   ```bash
   # run_at_unix_sec = now + 60
   grpcurl -plaintext -d '{"type":"hello","payload":"<base64>","options":{"run_at_unix_sec":'$(($(date +%s)+60))'}}' localhost:50051 job.v1.JobService/SubmitJob
   ```

**Real-time use:** High-priority tasks get more worker attention (queue weight 3); delayed job appears as “scheduled” until run_at.

---

### Scenario D: Failures and dead-letter queue (DLQ)

1. Submit a job that will fail (e.g. invalid email payload or unknown type).
2. After max retries, task moves to **archived** (DLQ).
3. **List archived:**
   ```bash
   grpcurl -plaintext -d '{"limit":50}' localhost:50051 job.v1.JobService/ListArchivedJobs
   ```
4. **Retry one:**
   ```bash
   grpcurl -plaintext -d '{"job_id":"<id>","queue":"default"}' localhost:50051 job.v1.JobService/RetryArchivedJob
   ```

**Real-time use:** Inspect failed jobs and re-queue them after fixing payload or system.

---

### Scenario E: Minikube (production-like)

1. Start Minikube, enable metrics-server, deploy Kafka and Postgres (or point to managed services).
2. Build images in Minikube Docker, apply `job-api` and `job-worker` manifests.
3. Workers run as Deployment (e.g. 2 replicas); API as Deployment; both use health/readiness probes.
4. **Real-time use:** Scale workers (`kubectl scale deployment job-worker --replicas=4`), hit API via port-forward or Ingress, scrape /metrics with Prometheus.

---

### Scenario F: Observability

- **Metrics (API):** `GET http://localhost:9090/metrics` — `jobs_enqueued_total`, `jobs_processed_total`, `job_processing_duration_seconds`.
- **Metrics (worker):** Worker exposes its own /metrics on :9090 (or :9091 in demo compose).
- **Logs:** Structured slog in API and worker (job_id, type, duration, errors).
- **Health:** API and worker expose HTTP /health and /ready (Postgres/Kafka checks).

**Real-time use:** Monitor queue growth, processing rate, latency, and failures; alert on readiness/health.

---

## 6. Environment Variables (reference)

| Variable | Default | Description |
|----------|---------|-------------|
| POSTGRES_DSN | (required) | Postgres DSN for job metadata. |
| KAFKA_BROKERS | (required) | Kafka broker list (e.g. `localhost:9092`). |
| GRPC_ADDR | :50051 | gRPC listen address (API). |
| METRICS_ADDR | :9090 | HTTP metrics listen (API). |
| WORKER_CONCURRENCY | 5 | Concurrent jobs per worker process. |
| SMTP_ADDR | (empty) | SMTP server (e.g. mailhog:1025). |
| EMAIL_FROM | noreply@localhost | From address for email jobs. |
| REPORT_OUTPUT_DIR | (empty) | Base directory for report output paths. |
| INVOICE_OUTPUT_DIR | (empty) | Base directory for invoice output. |
| IMAGE_OUTPUT_DIR | (empty) | Base directory for image output. |
| JOB_API_URL | (e.g. http://localhost:8083) | Used by dashboard to call Job API REST. |

---

## 7. Summary

- **What it is:** A distributed job queue with REST API, Kafka/Postgres backend, and pluggable job handlers (hello, email, image, invoice, report).
- **Architecture:** Clients → Job API (REST + metrics) → Kafka + Postgres → Workers (Registry → Handlers); optional dashboard, MailHog, Jaeger, Loki/Grafana for observability.
- **Real-time scenarios:** Local run, full demo (Docker), priority/delayed jobs, DLQ list/retry, Minikube deployment, and observability via metrics and health checks. Each component’s role is documented in the component table and job-type table above.
