package jobs

import (
	"context"
	"log/slog"
)

const HelloType = "hello"

// Hello is a no-op job that logs and succeeds (for Phase 1 validation).
type Hello struct{}

func (Hello) Type() string { return HelloType }

func (Hello) Handle(ctx context.Context, payload []byte) error {
	jobID := JobIDFromContext(ctx)
	slog.Info("hello job processed", "job_id", jobID, "payload", string(payload))
	return nil
}
