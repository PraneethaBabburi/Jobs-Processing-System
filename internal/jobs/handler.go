package jobs

import "context"

// Context key for current attempt (1-based). Set by the worker before calling Handle.
// Handlers can use this for demo behaviour (e.g. fail first N attempts).
type contextKey string

const AttemptContextKey contextKey = "attempt"
const JobIDContextKey contextKey = "job_id"

// JobIDFromContext returns the job ID from context if set by the worker; otherwise "".
func JobIDFromContext(ctx context.Context) string {
	if v := ctx.Value(JobIDContextKey); v != nil {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// Handler processes a job. Payload is the raw job payload bytes.
// Returning an error triggers retry (if retries left); nil marks the job complete.
type Handler interface {
	Type() string
	Handle(ctx context.Context, payload []byte) error
}
