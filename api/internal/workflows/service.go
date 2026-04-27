package workflows

import (
	"context"
	"fmt"
	"strings"

	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

type Service struct {
	repo workflowRepo
}

func NewService(repo workflowRepo) *Service {
	return &Service{repo: repo}
}

func (s *Service) ListWorkflows(ctx context.Context, in ListWorkflowsInput) (PaginatedWorkflows, error) {
	limit := in.Limit
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	out, err := s.repo.ListWorkflows(ctx, in.UserID, in.Cursor, limit)
	if err != nil {
		return PaginatedWorkflows{}, apperrors.ErrInternal()
	}
	return out, nil
}

func (s *Service) CreateWorkflow(ctx context.Context, in CreateWorkflowInput) (Workflow, error) {
	if strings.TrimSpace(in.Name) == "" {
		return Workflow{}, apperrors.ErrBadRequest("name is required")
	}

	for _, block := range in.Blocks {
		if err := s.validateBlock(ctx, block); err != nil {
			return Workflow{}, err
		}
	}

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return Workflow{}, apperrors.ErrInternal()
	}
	defer tx.Rollback(ctx)

	workflow, err := s.repo.CreateWorkflowTx(ctx, tx, in)
	if err != nil {
		return Workflow{}, apperrors.ErrInternal()
	}

	inserted, err := s.repo.InsertBlocksTx(ctx, tx, workflow.ID, in.Blocks)
	if err != nil {
		return Workflow{}, apperrors.ErrInternal()
	}
	workflow.Blocks = inserted

	if err := tx.Commit(ctx); err != nil {
		return Workflow{}, apperrors.ErrInternal()
	}

	return workflow, nil
}

func (s *Service) GetWorkflow(ctx context.Context, in GetWorkflowInput) (Workflow, error) {
	workflow, err := s.repo.GetWorkflowVisibleToUser(ctx, in.WorkflowID, in.UserID)
	if err != nil {
		if IsNotFound(err) {
			return Workflow{}, apperrors.ErrWorkflowNotFound()
		}
		return Workflow{}, apperrors.ErrInternal()
	}
	return workflow, nil
}

func (s *Service) UpdateWorkflow(ctx context.Context, in UpdateWorkflowInput) (Workflow, error) {
	if strings.TrimSpace(in.Name) == "" {
		return Workflow{}, apperrors.ErrBadRequest("name is required")
	}
	if in.UpdatedAt.IsZero() {
		return Workflow{}, apperrors.ErrBadRequest("updated_at is required")
	}

	ownerID, currentUpdatedAt, err := s.repo.GetOwnerAndUpdatedAt(ctx, in.WorkflowID)
	if err != nil {
		if IsNotFound(err) {
			return Workflow{}, apperrors.ErrWorkflowNotFound()
		}
		return Workflow{}, apperrors.ErrInternal()
	}

	if ownerID != in.UserID {
		return Workflow{}, apperrors.ErrForbidden()
	}

	if !currentUpdatedAt.Equal(in.UpdatedAt) {
		return Workflow{}, apperrors.ErrConflict(currentUpdatedAt)
	}

	for _, block := range in.Blocks {
		if err := s.validateBlock(ctx, block); err != nil {
			return Workflow{}, err
		}
	}

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return Workflow{}, apperrors.ErrInternal()
	}
	defer tx.Rollback(ctx)

	_, err = s.repo.UpdateWorkflowIfVersionMatchesTx(ctx, tx, in)
	if err != nil {
		if IsNotFound(err) {
			exists, existsErr := s.repo.WorkflowExistsForUser(ctx, in.WorkflowID, in.UserID)
			if existsErr != nil {
				return Workflow{}, apperrors.ErrInternal()
			}
			if !exists {
				return Workflow{}, apperrors.ErrWorkflowNotFound()
			}

			_, latestUpdatedAt, latestErr := s.repo.GetOwnerAndUpdatedAt(ctx, in.WorkflowID)
			if latestErr != nil {
				return Workflow{}, apperrors.ErrInternal()
			}
			return Workflow{}, apperrors.ErrConflict(latestUpdatedAt)
		}

		return Workflow{}, apperrors.ErrInternal()
	}

	if err := s.repo.ReplaceBlocksTx(ctx, tx, in.WorkflowID, in.Blocks); err != nil {
		return Workflow{}, apperrors.ErrInternal()
	}

	out, err := s.repo.GetWorkflowWithBlocksTx(ctx, tx, in.WorkflowID, in.UserID)
	if err != nil {
		if IsNotFound(err) {
			return Workflow{}, apperrors.ErrWorkflowNotFound()
		}
		return Workflow{}, apperrors.ErrInternal()
	}

	if err := tx.Commit(ctx); err != nil {
		return Workflow{}, apperrors.ErrInternal()
	}

	return out, nil
}

func (s *Service) DeleteWorkflow(ctx context.Context, in DeleteWorkflowInput) error {
	deleted, err := s.repo.DeleteWorkflowByOwner(ctx, in.WorkflowID, in.UserID)
	if err != nil {
		return apperrors.ErrInternal()
	}
	if !deleted {
		return apperrors.ErrWorkflowNotFound()
	}
	return nil
}

func (s *Service) CreateVersion(ctx context.Context, in CreateVersionInput) (WorkflowVersion, error) {
	ownerID, err := s.repo.GetWorkflowOwner(ctx, in.WorkflowID)
	if err != nil {
		if IsNotFound(err) {
			return WorkflowVersion{}, apperrors.ErrWorkflowNotFound()
		}
		return WorkflowVersion{}, apperrors.ErrInternal()
	}
	if ownerID != in.UserID {
		return WorkflowVersion{}, apperrors.ErrForbidden()
	}

	version, err := s.repo.CreateVersion(ctx, in.WorkflowID, in.CommitMessage, in.Snapshot)
	if err != nil {
		return WorkflowVersion{}, apperrors.ErrInternal()
	}
	return version, nil
}

func (s *Service) ListVersions(ctx context.Context, in ListVersionsInput) (PaginatedVersions, error) {
	limit := in.Limit
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	ownerID, err := s.repo.GetWorkflowOwner(ctx, in.WorkflowID)
	if err != nil {
		if IsNotFound(err) {
			return PaginatedVersions{}, apperrors.ErrWorkflowNotFound()
		}
		return PaginatedVersions{}, apperrors.ErrInternal()
	}
	if ownerID != in.UserID {
		return PaginatedVersions{}, apperrors.ErrForbidden()
	}

	versions, err := s.repo.ListVersions(ctx, in.WorkflowID, in.Cursor, limit)
	if err != nil {
		return PaginatedVersions{}, apperrors.ErrInternal()
	}
	return versions, nil
}

func (s *Service) validateBlock(ctx context.Context, block WorkflowBlock) error {
	if strings.TrimSpace(block.NodeTypeSlug) == "" {
		return apperrors.ErrBlockInvalid("node_type_slug is required")
	}

	schema, err := s.repo.GetNodeTypeSchema(ctx, block.NodeTypeSlug)
	if err != nil {
		if IsNotFound(err) {
			return apperrors.ErrBlockInvalid(fmt.Sprintf("unknown node_type_slug: %s", block.NodeTypeSlug))
		}
		return apperrors.ErrInternal()
	}

	if len(schema) == 0 {
		return nil
	}

	if block.Data == nil {
		return apperrors.ErrBlockInvalid("data is required for this node_type_slug")
	}

	for key, schemaValue := range schema {
		dataValue, exists := block.Data[key]
		if !exists {
			return apperrors.ErrBlockInvalid(fmt.Sprintf("missing data field %q", key))
		}
		if !isSameJSONType(schemaValue, dataValue) {
			return apperrors.ErrBlockInvalid(
				fmt.Sprintf(
					"invalid type for data field %q: expected %s, got %s",
					key, jsonTypeName(schemaValue), jsonTypeName(dataValue),
				),
			)
		}
	}

	for key := range block.Data {
		if _, exists := schema[key]; !exists {
			return apperrors.ErrBlockInvalid(
				fmt.Sprintf("unknown data field %q for node_type_slug %q", key, block.NodeTypeSlug),
			)
		}
	}

	return nil
}

func isSameJSONType(expected, actual any) bool {
	expectedType := jsonTypeName(expected)
	actualType := jsonTypeName(actual)

	if expectedType == "number" && actualType == "number" {
		return true
	}

	return expectedType == actualType
}

func jsonTypeName(value any) string {
	switch value.(type) {
	case nil:
		return "null"
	case bool:
		return "boolean"
	case string:
		return "string"
	case float32, float64, int, int8, int16, int32, int64, uint, uint8, uint16,
		uint32, uint64:
		return "number"
	case []any:
		return "array"
	case map[string]any:
		return "object"
	default:
		return fmt.Sprintf("%T", value)
	}
}
