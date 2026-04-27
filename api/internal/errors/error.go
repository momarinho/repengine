// Package errors defines the AppError type and helpers for creating and writing
// HTTP-aware application errors used across the API.
package errors

import (
	"errors"
	"maps"
	"net/http"
	"time"

	"github.com/gofiber/fiber/v2"
)

// AppError represents an application-level error that carries an HTTP status
// code, a machine-readable error code, a human-facing message, optional extra
// context data, and an optional underlying cause.
//
// AppError implements the error interface and supports errors.Is / errors.As
// through Unwrap.
type AppError struct {
	Status  int
	Code    string
	Message string
	Extra   map[string]any
	Cause   error
}

// Error implements the error interface and returns the error message.
// It returns an empty string if the receiver is nil to make calling Error()
// on a nil *AppError safe.
func (e *AppError) Error() string {
	if e == nil {
		return ""
	}
	return e.Message
}

// Unwrap returns the underlying cause so callers can use errors.Is / errors.As.
func (e *AppError) Unwrap() error {
	return e.Cause
}

// New creates a new AppError with the given HTTP status, machine-readable
// code and human-readable message.
func New(status int, code, message string) *AppError {
	return &AppError{
		Status:  status,
		Code:    code,
		Message: message,
	}
}

// WithExtra adds a key/value pair to the error's Extra map and returns the
// same error to allow fluent chaining (e.g. ErrConflict(...).WithExtra(...)).
func (e *AppError) WithExtra(key string, value any) *AppError {
	if e.Extra == nil {
		e.Extra = map[string]any{}
	}
	e.Extra[key] = value
	return e
}

// ErrWorkflowNotFound returns a 404 Not Found AppError for missing workflows.
func ErrWorkflowNotFound() *AppError {
	return New(http.StatusNotFound, "WORKFLOW_NOT_FOUND", "Workflow not found")
}

// ErrBlockInvalid returns 422 Unprocessable Entity for invalid workflow block.
// The provided message should describe the validation failure.
func ErrBlockInvalid(msg string) *AppError {
	return New(http.StatusUnprocessableEntity, "BLOCK_INVALID", msg)
}

// ErrConflict returns a 409 Conflict AppError used for optimistic concurrency
// errors. It adds the server's current updated timestamp as "current_updated_at"
// in RFC3339Nano (UTC) so clients can reconcile.
func ErrConflict(currentUpdateAt time.Time) *AppError {
	return New(http.StatusConflict, "CONFLICT", "Workflow was modified by another request").
		WithExtra("current_updated_at", currentUpdateAt.UTC().Format(time.RFC3339Nano))
}

// ErrUnauthorized returns a 401 Unauthorized AppError.
func ErrUnauthorized() *AppError {
	return New(http.StatusUnauthorized, "UNAUTHORIZED", "Unauthorized")
}

// ErrForbidden returns a 403 Forbidden AppError.
func ErrForbidden() *AppError {
	return New(http.StatusForbidden, "FORBIDDEN", "Forbidden")
}

// ErrBadRequest returns a 400 Bad Request AppError with a custom message.
func ErrBadRequest(msg string) *AppError {
	return New(http.StatusBadRequest, "BAD_REQUEST", msg)
}

// ErrInternal returns a generic 500 Internal Server Error AppError. Use it as
// a safe fallback when an error cannot be mapped to a more specific AppError.
func ErrInternal() *AppError {
	return New(http.StatusInternalServerError, "INTERNAL_ERROR", "Internal server error")
}

// WriteAppError writes the provided error to the HTTP response using Fiber.
// If err is not an *AppError it falls back to ErrInternal to avoid leaking
// implementation details. The JSON response contains "error" (code),
// "message" (human message), and any Extra fields merged into the payload.
func WriteAppError(c *fiber.Ctx, err error) error {
	var appErr *AppError
	if !errors.As(err, &appErr) {
		appErr = ErrInternal()
	}

	payload := fiber.Map{
		"error":   appErr.Code,
		"message": appErr.Message,
	}

	// Merge extra fields into the response payload. maps.Copy is a cheap
	// helper to copy keys from appErr.Extra into payload; it safely handles nil.
	maps.Copy(payload, appErr.Extra)

	return c.Status(appErr.Status).JSON(payload)
}
