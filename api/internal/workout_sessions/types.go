package workoutsessions

import "time"

const (
	SessionStatusActive    = "active"
	SessionStatusCompleted = "completed"
)

type WorkoutSession struct {
	ID           int             `json:"id"`
	WorkflowID   int             `json:"workflow_id"`
	UserID       int             `json:"user_id"`
	SectionID    string          `json:"section_id"`
	SectionTitle string          `json:"section_title"`
	Status       string          `json:"status"`
	StartedAt    time.Time       `json:"started_at"`
	CompletedAt  *time.Time      `json:"completed_at"`
	Notes        string          `json:"notes"`
	Logs         []WorkoutSetLog `json:"logs,omitempty"`
}

type WorkoutSetLog struct {
	ID                  int       `json:"id"`
	SessionID           int       `json:"session_id"`
	WorkflowBlockID     *int      `json:"workflow_block_id"`
	BlockClientID       string    `json:"block_client_id"`
	NodeTypeSlug        string    `json:"node_type_slug"`
	SetIndex            int       `json:"set_index"`
	PrescribedReps      string    `json:"prescribed_reps"`
	PrescribedLoad      string    `json:"prescribed_load"`
	PrescribedIntensity string    `json:"prescribed_intensity"`
	PrescribedRPE       string    `json:"prescribed_rpe"`
	ActualReps          string    `json:"actual_reps"`
	ActualLoad          string    `json:"actual_load"`
	ActualRPE           string    `json:"actual_rpe"`
	Completed           bool      `json:"completed"`
	Notes               string    `json:"notes"`
	CreatedAt           time.Time `json:"created_at"`
}

type PaginatedWorkoutSessions struct {
	Data       []WorkoutSession `json:"data"`
	NextCursor *int64           `json:"next_cursor"`
	HasMore    bool             `json:"has_more"`
}

type StartSessionInput struct {
	UserID       int
	WorkflowID   int
	SectionID    string
	SectionTitle string
}

type InsertSetLogInput struct {
	UserID              int
	SessionID           int
	WorkflowBlockID     *int
	BlockClientID       string
	NodeTypeSlug        string
	SetIndex            int
	PrescribedReps      string
	PrescribedLoad      string
	PrescribedIntensity string
	PrescribedRPE       string
	ActualReps          string
	ActualLoad          string
	ActualRPE           string
	Completed           bool
	Notes               string
}

type CompleteSessionInput struct {
	UserID    int
	SessionID int
	Notes     string
}

type GetSessionInput struct {
	UserID    int
	SessionID int
}

type ListSessionsInput struct {
	UserID     int
	WorkflowID int
	Cursor     int64
	Limit      int
}
