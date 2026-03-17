# Build from repo root: docker build -f deploy/stack/dashboard/Dockerfile .
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /dashboard ./cmd/dashboard

FROM alpine:3.19
RUN apk --no-cache add ca-certificates
COPY --from=builder /dashboard /dashboard
EXPOSE 8080
ENTRYPOINT ["/dashboard"]
