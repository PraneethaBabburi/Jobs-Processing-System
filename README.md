## Distributed Job Processing

This repo includes a phased implementation of a **distributed job processing system** for local development.

### Features

- **Job queue**: Kafka (topic `job.requests`); 
- **REST-only API**: Submit jobs, get status, list jobs, cancel, retry archived (DLQ); Admin: list queues (stubbed), pause/unpause (not supported in Kafka-only mode)
- **PostgreSQL**: Required for job metadata, status, and execution history
- **Kafka**: Job requests (topic `job.requests`), lifecycle events (topic `job.events`). 
- **Retries**: Configurable max retries; failed jobs re-enqueued to Kafka; exhausted jobs archived
- **Job types**: hello, email, image (resize), invoice (template), report (CSV)
- **Observability**: Structured logging (slog), Prometheus metrics (`/metrics`), health probes
- **Upstream servives**: user-service (register, password-reset), billing-service (invoice, report, email)

### Quick start (local)

1. **Start everything**:
  ```bash
   docker compose -f deploy/stack/docker-compose.yml up -d
  ```
2. **Apply Postgres schema** (once):
  ```bash
   docker exec -i $(docker compose -f deploy/stack/docker-compose.yml ps -q postgres) psql -U jobs jobs < deploy/postgres/schema.sql
  ```
   If port 5432 was in use, the stack uses **5433** on the host; to connect from the host use `-h localhost -p 5433`.
3. **Run the sample jobs script** (submits hello, email, report jobs; prints job IDs):
  ```bash
   ./scripts/run-sample-jobs.sh
  ```
   On Windows use the dashboard or Git Bash for `run-sample-jobs.sh`.

