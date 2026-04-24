package db

import (
	"context"
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
)

var Pool *pgxpool.Pool

func Connect() error {
	err := godotenv.Load()
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("godotenv: %w", err)
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return fmt.Errorf("DATABASE_URL is not set")
	}

	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return fmt.Errorf("parse config: %w", err)
	}

	config.MaxConns = 20
	config.MinConns = 2
	config.MaxConnLifetime = 1 * time.Hour
	config.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(context.Background(),
		config)
	if err != nil {
		return fmt.Errorf("new pool %w", err)
	}

	if err := pool.Ping(context.Background()); err != nil {
		return fmt.Errorf("ping: %w", err)
	}

	Pool = pool
	return nil
}

func Close() {
	if Pool != nil {
		Pool.Close()
	}
}

func RunMigrations(ctx context.Context) error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS users (
              id SERIAL PRIMARY KEY,
              email VARCHAR(255) NOT NULL UNIQUE,
              password_hash VARCHAR(255) NOT NULL,
              created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );`,
		`CREATE TABLE IF NOT EXISTS node_types (
              id SERIAL PRIMARY KEY,
              slug VARCHAR(50) NOT NULL UNIQUE,
              name VARCHAR(100) NOT NULL,
              description TEXT,
              icon VARCHAR(50) NOT NULL,
              schema JSONB NOT NULL DEFAULT '{}',
              created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );`,
		`CREATE TABLE IF NOT EXISTS workflows (
              id SERIAL PRIMARY KEY,
              user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              name VARCHAR(255) NOT NULL,
              description TEXT,
              is_public BOOLEAN NOT NULL DEFAULT FALSE,
              created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
              updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );`,
		`CREATE TABLE IF NOT EXISTS workflow_blocks (
              id SERIAL PRIMARY KEY,
              workflow_id INTEGER NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
              node_type_slug VARCHAR(50) NOT NULL REFERENCES node_types(slug),
              position INTEGER NOT NULL,
              data JSONB NOT NULL DEFAULT '{}',
              created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );`,
		`CREATE TABLE IF NOT EXISTS workflow_versions (
              id SERIAL PRIMARY KEY,
              workflow_id INTEGER NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
              version_number INTEGER NOT NULL,
              snapshot JSONB NOT NULL,
              commit_message VARCHAR(255),
              created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
              UNIQUE(workflow_id, version_number)
          );`,
	}
	for _, q := range queries {
		if _, err := Pool.Exec(ctx, q); err != nil {
			return err
		}
	}

	if _, err := Pool.Exec(ctx,
		`ALTER TABLE workflow_blocks ADD COLUMN IF NOT EXISTS id SERIAL`); err != nil {
		return err
	}

	indexQueries := []string{
		`CREATE INDEX IF NOT EXISTS idx_workflows_user_id ON workflows(user_id);`,
		`CREATE INDEX IF NOT EXISTS idx_workflow_blocks_workflow_id ON workflow_blocks(workflow_id);`,
		`CREATE INDEX IF NOT EXISTS idx_workflow_versions_workflow_id ON workflow_versions(workflow_id);`,
	}
	for _, q := range indexQueries {
		if _, err := Pool.Exec(ctx, q); err != nil {
			return err
		}
	}

	return nil
}

func SeedNodeTypes(ctx context.Context) error {
	seedData := []struct {
		slug, name, description, icon string
		schema                        string
	}{
		{"exercise", "Exercise", "A single exercise node", "dumbbell", "{}"},
		{"exercise_timed", "Timed Exercise", "Exercise with duration", "timer",
			`{"duration": 30}`},
		{"wave", "Wave", "Wave pattern for exercises", "activity", `{"sets": 3}`},
		{"repeat", "Repeat", "Repeat block", "repeat", `{"times": 3}`},
		{"rest", "Rest", "Rest period between sets", "pause", `{"duration": 30}`},
		{"section", "Section", "Section header", "folder", "{}"},
	}

	for _, n := range seedData {
		_, err := Pool.Exec(ctx,
			`INSERT INTO node_types (slug, name, description, icon, schema)
               VALUES ($1, $2, $3, $4, $5)
               ON CONFLICT (slug) DO NOTHING`,
			n.slug, n.name, n.description, n.icon, n.schema)
		if err != nil {
			return err
		}
	}
	return nil
}
