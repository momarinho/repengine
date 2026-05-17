package db

import (
	"context"
	"fmt"
	"io/fs"
	"log/slog"
	"sort"
	"strings"

	migrationfiles "github.com/momarinho/rep_engine/migrations"
)

// RunMigrations acquires a Postgres advisory lock, ensures the
// schema_migrations tracking table exists, and then applies any SQL files
// from the embedded migrations FS that have not yet been recorded.
//
// Each file is executed inside its own transaction so a failure leaves the
// database in a clean state for the next attempt.
func RunMigrations(ctx context.Context) error {
	const migrationLockID int64 = 20260517

	if _, err := Pool.Exec(ctx, `SELECT pg_advisory_lock($1)`, migrationLockID); err != nil {
		return fmt.Errorf("migrations: acquire advisory lock: %w", err)
	}
	defer func() {
		_, _ = Pool.Exec(context.Background(), `SELECT pg_advisory_unlock($1)`, migrationLockID)
	}()

	// Ensure the tracking table exists.
	_, err := Pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version    VARCHAR(255) PRIMARY KEY,
			applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		)
	`)
	if err != nil {
		return fmt.Errorf("migrations: create schema_migrations table: %w", err)
	}

	// Collect and sort SQL files by filename so they run in order.
	entries, err := fs.ReadDir(migrationfiles.FS, ".")
	if err != nil {
		return fmt.Errorf("migrations: read embedded FS: %w", err)
	}

	var filenames []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			filenames = append(filenames, e.Name())
		}
	}
	sort.Strings(filenames)

	for _, filename := range filenames {
		version := strings.TrimSuffix(filename, ".sql")

		// Check whether this version has already been applied.
		var count int
		if err := Pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM schema_migrations WHERE version = $1`,
			version,
		).Scan(&count); err != nil {
			return fmt.Errorf("migrations: check version %s: %w", version, err)
		}
		if count > 0 {
			continue // already applied — skip
		}

		content, err := migrationfiles.FS.ReadFile(filename)
		if err != nil {
			return fmt.Errorf("migrations: read file %s: %w", filename, err)
		}

		// Apply inside a transaction so a partial failure is rolled back.
		tx, err := Pool.Begin(ctx)
		if err != nil {
			return fmt.Errorf("migrations: begin tx for %s: %w", version, err)
		}

		if _, err := tx.Exec(ctx, string(content)); err != nil {
			_ = tx.Rollback(ctx)
			return fmt.Errorf("migrations: execute %s: %w", version, err)
		}

		if _, err := tx.Exec(ctx,
			`INSERT INTO schema_migrations (version) VALUES ($1)`,
			version,
		); err != nil {
			_ = tx.Rollback(ctx)
			return fmt.Errorf("migrations: record %s: %w", version, err)
		}

		if err := tx.Commit(ctx); err != nil {
			return fmt.Errorf("migrations: commit %s: %w", version, err)
		}

		slog.Info("applied migration", "version", version)
	}

	return nil
}
