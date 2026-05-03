package templates

import (
	"context"
	"fmt"
	"log/slog"
)

const cloneJobErrorMessageMaxLen = 500

type CloneWorker struct {
	repo        templateRepo
	maxAttempts int
}

func NewCloneWorker(repo templateRepo) *CloneWorker {
	return &CloneWorker{
		repo:        repo,
		maxAttempts: 3,
	}
}

func (w *CloneWorker) ProcessCloneJob(ctx context.Context, jobID int) {
	job, err := w.repo.GetCloneJobByID(ctx, jobID)
	if err != nil {
		slog.Error("failed to load clone job", "job_id", jobID, "err", err)
		return
	}

	if job.Status == CloneJobStatusCompleted || job.Status == CloneJobStatusRunning {
		return
	}

	startAttempt := job.Attempts + 1
	if startAttempt < 1 {
		startAttempt = 1
	}

	var lastErr error

	for attempt := startAttempt; attempt <= w.maxAttempts; attempt++ {
		if err := w.repo.MarkCloneJobRunning(ctx, jobID, attempt); err != nil {
			if w.shouldStopAfterRunLockFailure(ctx, jobID) {
				return
			}

			lastErr = fmt.Errorf("mark clone job running: %w", err)
			slog.Error("failed to mark clone job running", "job_id", jobID, "attempt", attempt,
				"err", err)

			if attempt == w.maxAttempts {
				w.markFailed(ctx, jobID, attempt, lastErr)
				return
			}
			continue
		}

		if err := w.processAttempt(ctx, job); err != nil {
			lastErr = err
			slog.Error("clone job attempt failed", "job_id", jobID, "attempt", attempt, "err",
				err)

			if attempt == w.maxAttempts {
				w.markFailed(ctx, jobID, attempt, err)
				return
			}
			continue
		}

		return
	}

	if lastErr != nil {
		w.markFailed(ctx, jobID, w.maxAttempts, lastErr)
	}
}

func (w *CloneWorker) processAttempt(ctx context.Context, job CloneJob) error {
	tpl, err := w.repo.GetTemplateByID(ctx, job.TemplateID)
	if err != nil {
		return fmt.Errorf("get template: %w", err)
	}

	blocks, err := w.repo.ListTemplateBlocks(ctx, job.TemplateID)
	if err != nil {
		return fmt.Errorf("list template blocks: %w", err)
	}

	tpl.Blocks = blocks

	tx, err := w.repo.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	workflowID, err := w.repo.CreateWorkflowFromTemplateTx(ctx, tx, job.UserID, tpl)
	if err != nil {
		return fmt.Errorf("create workflow from template: %w", err)
	}

	if err := w.repo.InsertWorkflowBlocksBatchTx(ctx, tx, workflowID, tpl.Blocks); err != nil {
		return fmt.Errorf("insert workflow blocks: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}

	if err := w.repo.MarkCloneJobCompleted(ctx, job.ID, workflowID); err != nil {
		return fmt.Errorf("mark clone job completed: %w", err)
	}

	return nil
}

func (w *CloneWorker) shouldStopAfterRunLockFailure(ctx context.Context, jobID int) bool {
	job, err := w.repo.GetCloneJobByID(ctx, jobID)
	if err != nil {
		return false
	}

	return job.Status == CloneJobStatusRunning || job.Status == CloneJobStatusCompleted
}

func (w *CloneWorker) markFailed(ctx context.Context, jobID, attempts int, err error) {
	message := truncateCloneJobError(err)

	if markErr := w.repo.MarkCloneJobFailed(ctx, jobID, attempts, message); markErr !=
		nil {
		slog.Error("failed to mark clone job as failed", "job_id", jobID, "err", markErr)
	}
}

func truncateCloneJobError(err error) string {
	if err == nil {
		return ""
	}

	msg := err.Error()
	if len(msg) <= cloneJobErrorMessageMaxLen {
		return msg
	}

	return msg[:cloneJobErrorMessageMaxLen-3] + "..."
}
