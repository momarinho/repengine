package authn

import "context"

type authRepo interface {
	CreateUser(ctx context.Context, email, passwordHash string) (User, error)
	FindUserByEmail(ctx context.Context, email string) (User, error)
	GetTokenVersionByUserID(ctx context.Context, userID int) (int, error)
	IncrementTokenVersion(ctx context.Context, userID int) error
}
