package templates

import (
	"context"
	"log/slog"
	"strings"

	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

type Service struct {
	repo   templateRepo
	worker *CloneWorker
}

func NewService(repo templateRepo, worker *CloneWorker) *Service {
	return &Service{
		repo:   repo,
		worker: worker,
	}
}

func (s *Service) ListTemplates(ctx context.Context, in ListTemplatesInput) (PaginatedTemplates, error) {
	limit := in.Limit
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	out, err := s.repo.ListTemplates(ctx, strings.TrimSpace(in.Category), in.Cursor, limit)
	if err != nil {
		return PaginatedTemplates{}, apperrors.ErrInternal()
	}

	return out, nil
}

func (s *Service) GetTemplate(ctx context.Context, in GetTemplateInput) (Template,
	error) {
	tpl, err := s.repo.GetTemplateByID(ctx, in.TemplateID)
	if err != nil {
		if IsNotFound(err) {
			return Template{}, apperrors.ErrTemplateNotFound()
		}
		return Template{}, apperrors.ErrInternal()
	}

	blocks, err := s.repo.ListTemplateBlocks(ctx, in.TemplateID)
	if err != nil {
		return Template{}, apperrors.ErrInternal()
	}

	tpl.Blocks = blocks
	return tpl, nil
}

func (s *Service) CloneTemplate(ctx context.Context, in CloneTemplateInput) (CloneJob, error) {
	if s.worker == nil {
		return CloneJob{}, apperrors.ErrInternal()
	}

	in.IdempotencyKey = strings.TrimSpace(in.IdempotencyKey)
	if in.IdempotencyKey == "" {
		return CloneJob{}, apperrors.ErrBadRequest("idempotency_key is required")
	}

	if _, err := s.repo.GetTemplateByID(ctx, in.TemplateID); err != nil {
		if IsNotFound(err) {
			return CloneJob{}, apperrors.ErrTemplateNotFound()
		}
		return CloneJob{}, apperrors.ErrInternal()
	}

	existing, err := s.repo.FindCloneJobByKey(ctx, in.TemplateID, in.UserID,
		in.IdempotencyKey)
	if err == nil {
		return existing, nil
	}
	if !IsNotFound(err) {
		return CloneJob{}, apperrors.ErrInternal()
	}

	job, err := s.repo.CreateCloneJob(ctx, in.TemplateID, in.UserID, in.IdempotencyKey)
	if err != nil {
		return CloneJob{}, apperrors.ErrInternal()
	}

	if job.Status == CloneJobStatusPending || job.Status == CloneJobStatusFailed {
		s.runCloneJobAsync(job.ID)
	}

	return job, nil
}

func (s *Service) GetCloneJob(ctx context.Context, in GetCloneJobInput) (CloneJob,
	error) {
	job, err := s.repo.GetCloneJob(ctx, in.JobID, in.UserID)
	if err != nil {
		if IsNotFound(err) {
			return CloneJob{}, apperrors.ErrCloneJobNotFound()
		}
		return CloneJob{}, apperrors.ErrInternal()
	}

	return job, nil
}

func (s *Service) runCloneJobAsync(jobID int) {
	go func() {
		if s.worker == nil {
			slog.Error("clone worker is not configured", "job_id", jobID)
			return
		}

		s.worker.ProcessCloneJob(context.Background(), jobID)
	}()
}
