package progressionstates

import "context"

type progressionStateRepo interface {
	UserOwnsWorkflow(ctx context.Context, userID, workflowID int) (bool, error)
	ListWorkflowBlocks(ctx context.Context, workflowID int) ([]workflowBlockConfig, error)
	ListProgressionStates(ctx context.Context, userID, workflowID int) ([]ProgressionState, error)
	UpsertProgressionState(ctx context.Context, in UpsertProgressionStateInput) (ProgressionState, error)
}
