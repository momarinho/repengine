package progressionstates

import "time"

const (
	StateTypeLinear = "linear"
	StateTypeWave   = "wave"
	StateTypeSkill  = "skill"

	OutcomeIncrease = "increase"
	OutcomeMaintain = "maintain"
	OutcomeReduce   = "reduce"
	OutcomeAdvance  = "advance"
	OutcomeRegress  = "regress"
)

type ProgressionState struct {
	ID                       int            `json:"id"`
	UserID                   int            `json:"user_id"`
	WorkflowID               int            `json:"workflow_id"`
	WorkflowBlockID          int            `json:"workflow_block_id"`
	BlockKey                 string         `json:"block_key"`
	NodeTypeSlug             string         `json:"node_type_slug"`
	StateType                string         `json:"state_type"`
	ExerciseName             string         `json:"exercise_name"`
	Outcome                  string         `json:"outcome"`
	CurrentLoad              string         `json:"current_load"`
	SuggestedLoad            string         `json:"suggested_load"`
	CurrentWeek              int            `json:"current_week"`
	SuggestedWeek            int            `json:"suggested_week"`
	SuggestedIntensityOffset string         `json:"suggested_intensity_offset"`
	AvgActualRPE             string         `json:"avg_actual_rpe"`
	AvgActualRIR             string         `json:"avg_actual_rir"`
	LastSessionID            int            `json:"last_session_id"`
	LastLogCount             int            `json:"last_log_count"`
	Summary                  string         `json:"summary"`
	Metadata                 map[string]any `json:"metadata"`
	CreatedAt                time.Time      `json:"created_at"`
	UpdatedAt                time.Time      `json:"updated_at"`
}

type CompletedSetLog struct {
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
	ActualRIR           string
	Completed           bool
	Notes               string
}

type HistoricalCompletedSetLog struct {
	SessionID int
	CompletedSetLog
}

type ApplySessionProgressionInput struct {
	UserID     int
	WorkflowID int
	SessionID  int
	Logs       []CompletedSetLog
}

type ListProgressionStatesInput struct {
	UserID     int
	WorkflowID int
}

type UpsertProgressionStateInput struct {
	UserID                   int
	WorkflowID               int
	WorkflowBlockID          int
	BlockKey                 string
	NodeTypeSlug             string
	StateType                string
	ExerciseName             string
	Outcome                  string
	CurrentLoad              string
	SuggestedLoad            string
	CurrentWeek              int
	SuggestedWeek            int
	SuggestedIntensityOffset string
	AvgActualRPE             string
	AvgActualRIR             string
	LastSessionID            int
	LastLogCount             int
	Summary                  string
	Metadata                 map[string]any
}

type workflowBlockConfig struct {
	ID           int
	NodeTypeSlug string
	Position     int
	Data         map[string]any
}
