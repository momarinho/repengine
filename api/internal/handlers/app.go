package handlers

import (
	"context"

	authnsvc "github.com/momarinho/rep_engine/internal/authn"
	progressionstatesvc "github.com/momarinho/rep_engine/internal/progression_states"
	templatesvc "github.com/momarinho/rep_engine/internal/templates"
	workflowsvc "github.com/momarinho/rep_engine/internal/workflows"
	workoutsessionsvc "github.com/momarinho/rep_engine/internal/workout_sessions"
)

type authService interface {
	Register(ctx context.Context, in authnsvc.RegisterInput) (authnsvc.RegisterResult, error)
	Login(ctx context.Context, in authnsvc.LoginInput) (authnsvc.LoginResult, error)
	Logout(ctx context.Context, userID int) error
}

type workflowService interface {
	ListWorkflows(ctx context.Context, in workflowsvc.ListWorkflowsInput) (workflowsvc.PaginatedWorkflows, error)
	CreateWorkflow(ctx context.Context, in workflowsvc.CreateWorkflowInput) (workflowsvc.Workflow, error)
	GetWorkflow(ctx context.Context, in workflowsvc.GetWorkflowInput) (workflowsvc.Workflow, error)
	UpdateWorkflow(ctx context.Context, in workflowsvc.UpdateWorkflowInput) (workflowsvc.Workflow, error)
	DeleteWorkflow(ctx context.Context, in workflowsvc.DeleteWorkflowInput) error
	CreateVersion(ctx context.Context, in workflowsvc.CreateVersionInput) (workflowsvc.WorkflowVersion, error)
	ListVersions(ctx context.Context, in workflowsvc.ListVersionsInput) (workflowsvc.PaginatedVersions, error)
}

type templateService interface {
	ListTemplates(ctx context.Context, in templatesvc.ListTemplatesInput) (templatesvc.PaginatedTemplates, error)
	GetTemplate(ctx context.Context, in templatesvc.GetTemplateInput) (templatesvc.Template, error)
	CloneTemplate(ctx context.Context, in templatesvc.CloneTemplateInput) (templatesvc.CloneJob, error)
	GetCloneJob(ctx context.Context, in templatesvc.GetCloneJobInput) (templatesvc.CloneJob, error)
}

type progressionStateService interface {
	ListProgressionStates(ctx context.Context, in progressionstatesvc.ListProgressionStatesInput) ([]progressionstatesvc.ProgressionState, error)
}

type workoutSessionService interface {
	ListSessions(ctx context.Context, in workoutsessionsvc.ListSessionsInput) (workoutsessionsvc.PaginatedWorkoutSessions, error)
	StartSession(ctx context.Context, in workoutsessionsvc.StartSessionInput) (workoutsessionsvc.WorkoutSession, error)
	GetSession(ctx context.Context, in workoutsessionsvc.GetSessionInput) (workoutsessionsvc.WorkoutSession, error)
	InsertSetLog(ctx context.Context, in workoutsessionsvc.InsertSetLogInput) (workoutsessionsvc.WorkoutSetLog, error)
	CompleteSession(ctx context.Context, in workoutsessionsvc.CompleteSessionInput) (workoutsessionsvc.WorkoutSession, error)
}

type Dependencies struct {
	Auth            authService
	Workflows       workflowService
	Templates       templateService
	Progression     progressionStateService
	WorkoutSessions workoutSessionService
	NodeTypes       map[string]NodeType
}

type App struct {
	auth            authService
	workflows       workflowService
	templates       templateService
	progression     progressionStateService
	workoutSessions workoutSessionService
	nodeTypes       map[string]NodeType
}

func NewApp(deps Dependencies) *App {
	nodeTypes := deps.NodeTypes
	if nodeTypes == nil {
		nodeTypes = map[string]NodeType{}
	}

	return &App{
		auth:            deps.Auth,
		workflows:       deps.Workflows,
		templates:       deps.Templates,
		progression:     deps.Progression,
		workoutSessions: deps.WorkoutSessions,
		nodeTypes:       nodeTypes,
	}
}
