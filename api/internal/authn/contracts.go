package authn

import "context"

type authRepo interface {
	CreateUser(ctx context.Context, email, passwordHash string) (User, error)
	FindUserByEmail(ctx context.Context, email string) (User, error)
	FindUserByID(ctx context.Context, userID int) (User, error)
	GetTokenVersionByUserID(ctx context.Context, userID int) (int, error)
	IncrementTokenVersion(ctx context.Context, userID int) error
	UpdateUserCredentials(ctx context.Context, userID int, email *string, passwordHash *string) (User, error)
	DeleteUser(ctx context.Context, userID int) error
	CreatePasswordResetToken(ctx context.Context, userID int, tokenHash string, expiresAt int64) error
	ConsumePasswordResetToken(ctx context.Context, tokenHash, passwordHash string) error
}
