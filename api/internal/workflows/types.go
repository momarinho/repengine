package workflows

import "time"

type Workflow struct {
	ID          int             `json:"id"`
	UserID      int             `json:"user_id"`
	Name        string          `json:"name"`
	Description string          `json:"description"`
	IsPublic    bool            `json:"is_public"`
	CreatedAt   time.Time       `json:"created_at"`
	UpdatedAt   time.Time       `json:"updated_at"`
	Blocks      []WorkflowBlock `json:"blocks,omitempty"`
}

type WorkflowBlock struct {
	ID           int            `json:"id"`
	WorkflowID   int            `json:"workflow_id"`
	NodeTypeSlug string         `json:"node_type_slug"`
	Position     int            `json:"position"`
	Data         map[string]any `json:"data"`
}

type UpdateWorkflowInput struct {
	WorkflowID int
	UserID     int

	Name        string
	Description string
	IsPublic    *bool

	UpdatedAt time.Time

	Blocks []WorkflowBlock
}

type PersistResult struct {
	Workflow Workflow `json:"workflow"`
}

type PaginatedWorkflows struct {
	Data       []Workflow `json:"data"`
	NextCursor *int64     `json:"next_cursor"`
	HasMore    bool       `json:"has_more"`
}

type WorkflowVersion struct {
	ID            int            `json:"id"`
	WorkflowID    int            `json:"workflow_id"`
	VersionNumber int            `json:"version_number"`
	Snapshot      map[string]any `json:"snapshot"`
	CommitMessage string         `json:"commit_message"`
	CreatedAt     time.Time      `json:"created_at"`
}

type PaginatedVersions struct {
	Data       []WorkflowVersion `json:"data"`
	NextCursor *int64            `json:"next_cursor"`
	HasMore    bool              `json:"has_more"`
}

type CreateWorkflowInput struct {
	UserID      int
	Name        string
	Description string
	IsPublic    bool
	Blocks      []WorkflowBlock
}

type GetWorkflowInput struct {
	UserID     int
	WorkflowID int
}

type ListWorkflowsInput struct {
	UserID int
	Cursor int64
	Limit  int
}

type DeleteWorkflowInput struct {
	UserID     int
	WorkflowID int
}

type CreateVersionInput struct {
	UserID        int
	WorkflowID    int
	CommitMessage string
	Snapshot      map[string]any
}

type ListVersionsInput struct {
	UserID     int
	WorkflowID int
	Cursor     int64
	Limit      int
}
