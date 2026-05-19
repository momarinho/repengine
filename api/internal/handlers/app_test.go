package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
	authnsvc "github.com/momarinho/rep_engine/internal/authn"
	apperrors "github.com/momarinho/rep_engine/internal/errors"
	workflowsvc "github.com/momarinho/rep_engine/internal/workflows"
)

type fakeAuthService struct {
	registerFunc func(ctx context.Context, in authnsvc.RegisterInput) (authnsvc.RegisterResult, error)
	loginFunc    func(ctx context.Context, in authnsvc.LoginInput) (authnsvc.LoginResult, error)
	logoutFunc   func(ctx context.Context, userID int) error
}

func (f *fakeAuthService) Register(ctx context.Context, in authnsvc.RegisterInput) (authnsvc.RegisterResult, error) {
	if f.registerFunc == nil {
		panic("unexpected call to Register")
	}
	return f.registerFunc(ctx, in)
}

func (f *fakeAuthService) Login(ctx context.Context, in authnsvc.LoginInput) (authnsvc.LoginResult, error) {
	if f.loginFunc == nil {
		panic("unexpected call to Login")
	}
	return f.loginFunc(ctx, in)
}

func (f *fakeAuthService) Logout(ctx context.Context, userID int) error {
	if f.logoutFunc == nil {
		panic("unexpected call to Logout")
	}
	return f.logoutFunc(ctx, userID)
}

func (f *fakeAuthService) GetAccount(ctx context.Context, userID int) (authnsvc.Account, error) {
	panic("unexpected call to GetAccount")
}

func (f *fakeAuthService) UpdateAccount(ctx context.Context, in authnsvc.UpdateAccountInput) (authnsvc.UpdateAccountResult, error) {
	panic("unexpected call to UpdateAccount")
}

func (f *fakeAuthService) DeleteAccount(ctx context.Context, in authnsvc.DeleteAccountInput) error {
	panic("unexpected call to DeleteAccount")
}

func (f *fakeAuthService) RequestPasswordReset(ctx context.Context, in authnsvc.RequestPasswordResetInput) (authnsvc.RequestPasswordResetResult, error) {
	panic("unexpected call to RequestPasswordReset")
}

func (f *fakeAuthService) ResetPassword(ctx context.Context, in authnsvc.ResetPasswordInput) error {
	panic("unexpected call to ResetPassword")
}

type fakeWorkflowService struct {
	createVersionFunc func(ctx context.Context, in workflowsvc.CreateVersionInput) (workflowsvc.WorkflowVersion, error)
}

func (f *fakeWorkflowService) ListWorkflows(ctx context.Context, in workflowsvc.ListWorkflowsInput) (workflowsvc.PaginatedWorkflows, error) {
	panic("unexpected call to ListWorkflows")
}

func (f *fakeWorkflowService) CreateWorkflow(ctx context.Context, in workflowsvc.CreateWorkflowInput) (workflowsvc.Workflow, error) {
	panic("unexpected call to CreateWorkflow")
}

func (f *fakeWorkflowService) GetWorkflow(ctx context.Context, in workflowsvc.GetWorkflowInput) (workflowsvc.Workflow, error) {
	panic("unexpected call to GetWorkflow")
}

func (f *fakeWorkflowService) UpdateWorkflow(ctx context.Context, in workflowsvc.UpdateWorkflowInput) (workflowsvc.Workflow, error) {
	panic("unexpected call to UpdateWorkflow")
}

func (f *fakeWorkflowService) DeleteWorkflow(ctx context.Context, in workflowsvc.DeleteWorkflowInput) error {
	panic("unexpected call to DeleteWorkflow")
}

func (f *fakeWorkflowService) CreateVersion(ctx context.Context, in workflowsvc.CreateVersionInput) (workflowsvc.WorkflowVersion, error) {
	if f.createVersionFunc == nil {
		panic("unexpected call to CreateVersion")
	}
	return f.createVersionFunc(ctx, in)
}

func (f *fakeWorkflowService) ListVersions(ctx context.Context, in workflowsvc.ListVersionsInput) (workflowsvc.PaginatedVersions, error) {
	panic("unexpected call to ListVersions")
}

func (f *fakeWorkflowService) RestoreVersion(ctx context.Context, in workflowsvc.RestoreVersionInput) (workflowsvc.Workflow, error) {
	panic("unexpected call to RestoreVersion")
}

func decodeBody(t *testing.T, resp *http.Response) map[string]any {
	t.Helper()

	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode response body: %v", err)
	}

	return body
}

func TestRegister_InvalidJSON_ReturnsBadRequest(t *testing.T) {
	authCalled := false
	h := NewApp(Dependencies{
		Auth: &fakeAuthService{
			registerFunc: func(ctx context.Context, in authnsvc.RegisterInput) (authnsvc.RegisterResult, error) {
				authCalled = true
				return authnsvc.RegisterResult{}, nil
			},
		},
	})

	app := fiber.New()
	app.Post("/auth/register", h.Register)

	req := httptest.NewRequest("POST", "/auth/register", bytes.NewBufferString("{"))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test returned error: %v", err)
	}

	if resp.StatusCode != fiber.StatusBadRequest {
		t.Fatalf("expected 400, got %d", resp.StatusCode)
	}
	if authCalled {
		t.Fatal("expected auth service not to be called on invalid JSON")
	}
}

func TestLogin_SetsCookieAndReturnsPayload(t *testing.T) {
	var gotInput authnsvc.LoginInput
	h := NewApp(Dependencies{
		Auth: &fakeAuthService{
			loginFunc: func(ctx context.Context, in authnsvc.LoginInput) (authnsvc.LoginResult, error) {
				gotInput = in
				return authnsvc.LoginResult{
					UserID: 7,
					Token:  "signed-token",
				}, nil
			},
		},
	})

	app := fiber.New()
	app.Post("/auth/login", h.Login)

	req := httptest.NewRequest("POST", "/auth/login", bytes.NewBufferString(`{"email":"user@example.com","password":"password123"}`))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test returned error: %v", err)
	}

	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	if gotInput.Email != "user@example.com" || gotInput.Password != "password123" {
		t.Fatalf("unexpected login input: %+v", gotInput)
	}

	body := decodeBody(t, resp)
	if body["token"] != "signed-token" {
		t.Fatalf("expected token signed-token, got %#v", body["token"])
	}
	if body["user_id"] != float64(7) {
		t.Fatalf("expected user_id 7, got %#v", body["user_id"])
	}

	foundCookie := false
	for _, cookie := range resp.Cookies() {
		if cookie.Name == "token" && cookie.Value == "signed-token" {
			foundCookie = true
			break
		}
	}
	if !foundCookie {
		t.Fatal("expected token cookie to be set")
	}
}

func TestCreateVersion_UsesRouteWorkflowAndUserContext(t *testing.T) {
	var gotInput workflowsvc.CreateVersionInput
	h := NewApp(Dependencies{
		Workflows: &fakeWorkflowService{
			createVersionFunc: func(ctx context.Context, in workflowsvc.CreateVersionInput) (workflowsvc.WorkflowVersion, error) {
				gotInput = in
				return workflowsvc.WorkflowVersion{
					ID:            10,
					WorkflowID:    in.WorkflowID,
					VersionNumber: 3,
					CommitMessage: in.CommitMessage,
					Snapshot:      in.Snapshot,
				}, nil
			},
		},
	})

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", 42)
		return c.Next()
	})
	app.Post("/workflows/:id/versions", h.CreateVersion)

	req := httptest.NewRequest("POST", "/workflows/99/versions", bytes.NewBufferString(`{"commit_message":"save point","snapshot":{"name":"Treino A"}}`))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test returned error: %v", err)
	}

	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("expected 201, got %d", resp.StatusCode)
	}
	if gotInput.UserID != 42 || gotInput.WorkflowID != 99 || gotInput.CommitMessage != "save point" {
		t.Fatalf("unexpected CreateVersion input: %+v", gotInput)
	}

	body := decodeBody(t, resp)
	if body["workflow_id"] != float64(99) {
		t.Fatalf("expected workflow_id 99, got %#v", body["workflow_id"])
	}
	if body["version_number"] != float64(3) {
		t.Fatalf("expected version_number 3, got %#v", body["version_number"])
	}
}

func TestCreateVersion_MapsServiceError(t *testing.T) {
	h := NewApp(Dependencies{
		Workflows: &fakeWorkflowService{
			createVersionFunc: func(ctx context.Context, in workflowsvc.CreateVersionInput) (workflowsvc.WorkflowVersion, error) {
				return workflowsvc.WorkflowVersion{}, apperrors.ErrForbidden()
			},
		},
	})

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", 42)
		return c.Next()
	})
	app.Post("/workflows/:id/versions", h.CreateVersion)

	req := httptest.NewRequest("POST", "/workflows/99/versions", bytes.NewBufferString(`{"commit_message":"save point","snapshot":{}}`))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test returned error: %v", err)
	}

	if resp.StatusCode != fiber.StatusForbidden {
		t.Fatalf("expected 403, got %d", resp.StatusCode)
	}
}
