# Minikube Kafka + Postgres Demo

This folder contains Kubernetes manifests for running the **current** repo architecture on **Minikube**:

- **Kafka (KRaft)** for job queueing (`job.requests`, `job.events`)
- **PostgreSQL** for job metadata/status
- **job-api** (REST) + **job-worker** + **job-scheduler**
- **dashboard** (cmd/dashboard UI)
- **Mailpit** for capturing emails (SMTP + web UI)

It is intentionally separate from the existing `deploy/minikube/*.yaml` folder, so your existing Docker Compose setup and older Minikube manifests are not disturbed.

## 1. Start Minikube

```bash
minikube start
minikube addons enable metrics-server
```

## 2. Build/load local images into Minikube

This repo’s k8s manifests reference these image tags:

- `job-api:latest`
- `job-worker:latest`
- `job-scheduler:latest`
- `dashboard:latest`

Build them inside Minikube’s Docker daemon:

```bash
eval "$(minikube docker-env)"
docker build -t job-api:latest -f Dockerfile.api .
docker build -t job-worker:latest -f Dockerfile.worker .
docker build -t job-scheduler:latest -f Dockerfile.scheduler .
docker build -t dashboard:latest -f deploy/stack/dashboard/Dockerfile .
```

## 3. Apply infrastructure (Postgres, Kafka, init topics, Mailpit)

```bash
kubectl apply -f deploy/minikube/kafka-postgres/postgres.yaml
kubectl apply -f deploy/minikube/kafka-postgres/kafka.yaml
kubectl apply -f deploy/minikube/kafka-postgres/kafka-init.yaml
kubectl apply -f deploy/minikube/kafka-postgres/mailpit.yaml
```

Wait for pods to become ready:

```bash
kubectl get pods
kubectl get pods -l app=postgres
kubectl get pods -l app=kafka
```

## 3b. (Optional) Loki + Grafana for logs

If you want to view logs in the Grafana UI (instead of `kubectl logs`):

```bash
kubectl apply -f deploy/minikube/kafka-postgres/loki.yaml
kubectl apply -f deploy/minikube/kafka-postgres/promtail.yaml
kubectl apply -f deploy/minikube/kafka-postgres/grafana.yaml
```

Wait for Grafana/Loki/Promtail:

```bash
kubectl get pods -l app=loki
kubectl get pods -l app=promtail
kubectl get pods -l app=grafana
```

## 4. Apply PostgreSQL schema (required)

```bash
POSTGRES_POD=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -i "$POSTGRES_POD" -- psql -U jobs jobs < deploy/postgres/schema.sql
```

## 5. Apply app services (job-api, job-worker, job-scheduler, dashboard)

```bash
kubectl apply -f deploy/minikube/kafka-postgres/job-api.yaml
kubectl apply -f deploy/minikube/kafka-postgres/job-worker.yaml
kubectl apply -f deploy/minikube/kafka-postgres/job-scheduler.yaml
kubectl apply -f deploy/minikube/kafka-postgres/dashboard.yaml
```

## 6. Port-forward to access the REST API + Dashboard

job-api listens on port `8080` in the container.

```bash
kubectl port-forward svc/job-api 8083:8080
```

Then you can call:

- `http://localhost:8083/jobs`
- `http://localhost:8083/admin/queues`
- `http://localhost:8083/metrics`

Dashboard UI:
```bash
kubectl port-forward svc/dashboard 8080:8080
```
Then open:
- `http://localhost:8080`

## 7. Check email UI

Mailpit UI listens on container port `8025`.

```bash
kubectl port-forward svc/mailpit 8026:8025
```

Then open: `http://localhost:8026`

## 8. Verify logs in Grafana (Loki)

```bash
kubectl port-forward svc/grafana 3000:3000
```

Open:
- http://localhost:3000

Login: `admin` / `admin`

In **Explore** (Loki datasource is pre-configured), try:

- `{app="job-api"}`
- `{app="job-worker"}`
- `{app="job-scheduler"}`

