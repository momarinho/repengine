package authn

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type User struct {
	ID           int
	Email        string
	PasswordHash string
	TokenVersion int
}

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) CreateUser(ctx context.Context, email, passwordHash string) (User, error) {
	var user User
	err := r.pool.QueryRow(ctx, `
		INSERT INTO users (email, password_hash)
		VALUES ($1, $2)
		RETURNING id, email, password_hash, token_version
	`, email, passwordHash).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.TokenVersion,
	)
	if err != nil {
		return User{}, err
	}

	return user, nil
}

func (r *Repository) FindUserByEmail(ctx context.Context, email string) (User, error) {
	var user User
	err := r.pool.QueryRow(ctx, `
		SELECT id, email, password_hash, token_version
		FROM users
		WHERE LOWER(email) = $1
	`, NormalizeEmail(email)).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.TokenVersion,
	)
	if err != nil {
		return User{}, err
	}

	return user, nil
}

func (r *Repository) GetTokenVersionByUserID(ctx context.Context, userID int) (int, error) {
	var tokenVersion int
	err := r.pool.QueryRow(ctx, `
		SELECT token_version
		FROM users
		WHERE id = $1
	`, userID).Scan(&tokenVersion)
	if err != nil {
		return 0, err
	}

	return tokenVersion, nil
}

func (r *Repository) IncrementTokenVersion(ctx context.Context, userID int) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE users
		SET token_version = token_version + 1
		WHERE id = $1
	`, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	return nil
}

func IsNotFound(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}

func IsUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
