package authn

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type User struct {
	ID           int
	Email        string
	PasswordHash string
	TokenVersion int
	CreatedAt    time.Time
	UpdatedAt    time.Time
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
		RETURNING id, email, password_hash, token_version, created_at, updated_at
	`, email, passwordHash).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.TokenVersion,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		return User{}, err
	}

	return user, nil
}

func (r *Repository) FindUserByEmail(ctx context.Context, email string) (User, error) {
	var user User
	err := r.pool.QueryRow(ctx, `
		SELECT id, email, password_hash, token_version, created_at, updated_at
		FROM users
		WHERE LOWER(email) = $1
	`, NormalizeEmail(email)).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.TokenVersion,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		return User{}, err
	}

	return user, nil
}

func (r *Repository) FindUserByID(ctx context.Context, userID int) (User, error) {
	var user User
	err := r.pool.QueryRow(ctx, `
		SELECT id, email, password_hash, token_version, created_at, updated_at
		FROM users
		WHERE id = $1
	`, userID).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.TokenVersion,
		&user.CreatedAt,
		&user.UpdatedAt,
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

func (r *Repository) UpdateUserCredentials(ctx context.Context, userID int, email *string, passwordHash *string) (User, error) {
	var user User
	err := r.pool.QueryRow(ctx, `
		UPDATE users
		SET
			email = COALESCE($2, email),
			password_hash = COALESCE($3, password_hash),
			token_version = token_version + 1,
			updated_at = NOW()
		WHERE id = $1
		RETURNING id, email, password_hash, token_version, created_at, updated_at
	`, userID, email, passwordHash).Scan(
		&user.ID,
		&user.Email,
		&user.PasswordHash,
		&user.TokenVersion,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		return User{}, err
	}

	return user, nil
}

func (r *Repository) DeleteUser(ctx context.Context, userID int) error {
	tag, err := r.pool.Exec(ctx, `
		DELETE FROM users
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

func (r *Repository) CreatePasswordResetToken(ctx context.Context, userID int, tokenHash string, expiresAt int64) error {
	tag, err := r.pool.Exec(ctx, `
		INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, to_timestamp($3))
	`, userID, tokenHash, expiresAt)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	return nil
}

func (r *Repository) ConsumePasswordResetToken(ctx context.Context, tokenHash, passwordHash string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var userID int
	var expiresAt time.Time
	var usedAt *time.Time
	err = tx.QueryRow(ctx, `
		SELECT user_id, expires_at, used_at
		FROM password_reset_tokens
		WHERE token_hash = $1
		FOR UPDATE
	`, tokenHash).Scan(&userID, &expiresAt, &usedAt)
	if err != nil {
		return err
	}

	if usedAt != nil || !expiresAt.After(time.Now().UTC()) {
		return pgx.ErrNoRows
	}

	tag, err := tx.Exec(ctx, `
		UPDATE users
		SET
			password_hash = $2,
			token_version = token_version + 1,
			updated_at = NOW()
		WHERE id = $1
	`, userID, passwordHash)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	tag, err = tx.Exec(ctx, `
		UPDATE password_reset_tokens
		SET used_at = NOW()
		WHERE token_hash = $1
		  AND used_at IS NULL
	`, tokenHash)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}

	if err := tx.Commit(ctx); err != nil {
		return err
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
