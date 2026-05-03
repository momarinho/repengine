package templates

import "time"

const (
	CloneJobStatusPending   = "pending"
	CloneJobStatusRunning   = "running"
	CloneJobStatusCompleted = "completed"
	CloneJobStatusFailed    = "failed"
)

type Template struct {
	ID          int             `json:"id"`
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Category    string          `json:"category"`
	IsOfficial  bool            `json:"is_official"`
	AuthorID    *int            `json:"author_id"`
	Metadata    map[string]any  `json:"metadata"`
	CreatedAt   time.Time       `json:"created_at"`
	Blocks      []TemplateBlock `json:"blocks,omitempty"`
}

type TemplateBlock struct {
	ID           int            `json:"id"`
	TemplateID   int            `json:"template_id"`
	NodeTypeSlug string         `json:"node_type_slug"`
	Position     int            `json:"position"`
	Data         map[string]any `json:"data"`
	CreatedAt    time.Time      `json:"created_at"`
}

type CloneJob struct {
	ID             int       `json:"id"`
	TemplateID     int       `json:"template_id"`
	UserID         int       `json:"user_id"`
	WorkflowID     *int      `json:"workflow_id"`
	IdempotencyKey string    `json:"idempotency_key"`
	Status         string    `json:"status"`
	Attempts       int       `json:"attempts"`
	ErrorMessage   string    `json:"error_message"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type PaginatedTemplates struct {
	Data       []Template `json:"data"`
	NextCursor *int64     `json:"next_cursor"`
	HasMore    bool       `json:"has_more"`
}

type ListTemplatesInput struct {
	UserID   int
	Category string
	Cursor   int64
	Limit    int
}

type GetTemplateInput struct {
	UserID     int
	TemplateID int
}

type CloneTemplateInput struct {
	UserID         int
	TemplateID     int
	IdempotencyKey string
}

type GetCloneJobInput struct {
	UserID int
	JobID  int
}
