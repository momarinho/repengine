package db

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
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
		`CREATE TABLE IF NOT EXISTS templates (
              id SERIAL PRIMARY KEY,
              name VARCHAR(255) NOT NULL,
              description TEXT,
              category VARCHAR(50) NOT NULL,
              is_official BOOLEAN NOT NULL DEFAULT FALSE,
              author_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
              metadata JSONB NOT NULL DEFAULT '{}',
              created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );`,
		`CREATE TABLE IF NOT EXISTS template_blocks (
              id SERIAL PRIMARY KEY,
              template_id INTEGER NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
              node_type_slug VARCHAR(50) NOT NULL REFERENCES node_types(slug),
              position INTEGER NOT NULL,
              data JSONB NOT NULL DEFAULT '{}',
              created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );`,
		`CREATE TABLE IF NOT EXISTS clone_jobs (
              id SERIAL PRIMARY KEY,
              template_id INTEGER NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
              user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              workflow_id INTEGER REFERENCES workflows(id) ON DELETE SET NULL,
              idempotency_key VARCHAR(100) NOT NULL,
              status VARCHAR(20) NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,
              error_message TEXT,
              created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
              updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
              UNIQUE(template_id, user_id, idempotency_key)
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
		`CREATE INDEX IF NOT EXISTS idx_template_blocks_template_id ON template_blocks(template_id);`,
		`CREATE INDEX IF NOT EXISTS idx_clone_jobs_user_id ON clone_jobs(user_id);`,
		`CREATE INDEX IF NOT EXISTS idx_clone_jobs_template_user_key ON clone_jobs(template_id, user_id, idempotency_key);`,
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

type templateSeed struct {
	Name        string
	Description string
	Category    string
	IsOfficial  bool
	Metadata    map[string]any
	Blocks      []templateBlockSeed
}

type templateBlockSeed struct {
	NodeTypeSlug string
	Data         map[string]any
}

func SeedTemplates(ctx context.Context) error {
	seeds := []templateSeed{
		{
			Name:        "5/3/1",
			Description: "Jim Wendler 5/3/1 base template for main barbell lifts.",
			Category:    "strength",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "4 weeks",
				"frequency": "4 days/week",
				"level":     "intermediate",
			},
			Blocks: []templateBlockSeed{
				{
					NodeTypeSlug: "section",
					Data: map[string]any{
						"title": "Day 1 - Squat",
					},
				},
				{
					NodeTypeSlug: "wave",
					Data: map[string]any{
						"exercise_name":     "Squat",
						"week":              "week_1",
						"reps":              "5/5/5+",
						"intensity_percent": "65/75/85",
						"rpe":               "8-9",
					},
				},
				{
					NodeTypeSlug: "rest",
					Data: map[string]any{
						"duration": 120,
					},
				},
				{
					NodeTypeSlug: "exercise",
					Data: map[string]any{
						"exercise_name": "Romanian Deadlift",
						"sets":          3,
						"reps":          "8",
					},
				},
				{
					NodeTypeSlug: "section",
					Data: map[string]any{
						"title": "Day 2 - Bench Press",
					},
				},
				{
					NodeTypeSlug: "wave",
					Data: map[string]any{
						"exercise_name":     "Bench Press",
						"week":              "week_1",
						"reps":              "5/5/5+",
						"intensity_percent": "65/75/85",
						"rpe":               "8-9",
					},
				},
				{
					NodeTypeSlug: "rest",
					Data: map[string]any{
						"duration": 120,
					},
				},
				{
					NodeTypeSlug: "exercise",
					Data: map[string]any{
						"exercise_name": "Barbell Row",
						"sets":          3,
						"reps":          "10",
					},
				},
			},
		},
		{
			Name:        "GZCLP",
			Description: "Linear progression template with T1, T2 and T3 structure.",
			Category:    "strength",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "12 weeks",
				"frequency": "4 days/week",
				"level":     "beginner",
			},
			Blocks: []templateBlockSeed{
				{
					NodeTypeSlug: "section",
					Data: map[string]any{
						"title": "T1 Main Lift",
					},
				},
				{
					NodeTypeSlug: "wave",
					Data: map[string]any{
						"exercise_name": "Squat",
						"sets":          5,
						"reps":          "3",
						"progression":   "+5 lb/session",
					},
				},
				{
					NodeTypeSlug: "rest",
					Data: map[string]any{
						"duration": 180,
					},
				},
				{
					NodeTypeSlug: "section",
					Data: map[string]any{
						"title": "T2 Secondary Lift",
					},
				},
				{
					NodeTypeSlug: "exercise",
					Data: map[string]any{
						"exercise_name": "Bench Press",
						"sets":          3,
						"reps":          "10",
					},
				},
				{
					NodeTypeSlug: "rest",
					Data: map[string]any{
						"duration": 90,
					},
				},
				{
					NodeTypeSlug: "section",
					Data: map[string]any{
						"title": "T3 Accessories",
					},
				},
				{
					NodeTypeSlug: "exercise",
					Data: map[string]any{
						"exercise_name": "Lat Pulldown",
						"sets":          3,
						"reps":          "15",
					},
				},
			},
		},
	}

	tx, err := Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin template seed tx: %w", err)
	}
	defer tx.Rollback(ctx)

	for _, seed := range seeds {
		templateID, err := upsertTemplateSeed(ctx, tx, seed)
		if err != nil {
			return err
		}

		if _, err := tx.Exec(ctx, `DELETE FROM template_blocks WHERE template_id = $1`, templateID); err != nil {
			return fmt.Errorf("delete template blocks for template %d: %w", templateID, err)
		}

		for i, block := range seed.Blocks {
			dataJSON, err := json.Marshal(block.Data)
			if err != nil {
				return fmt.Errorf("marshal template block data: %w", err)
			}

			if _, err := tx.Exec(ctx, `
				INSERT INTO template_blocks (template_id, node_type_slug, position, data)
				VALUES ($1, $2, $3, $4)
			`, templateID, block.NodeTypeSlug, i, dataJSON); err != nil {
				return fmt.Errorf("insert template block for template %d: %w", templateID, err)
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit template seed tx: %w", err)
	}

	return nil
}

func upsertTemplateSeed(ctx context.Context, tx pgx.Tx, seed templateSeed) (int, error) {
	metadataJSON, err := json.Marshal(seed.Metadata)
	if err != nil {
		return 0, fmt.Errorf("marshal template metadata: %w", err)
	}

	var templateID int
	err = tx.QueryRow(ctx, `
 		SELECT id
 		FROM templates
 		WHERE name = $1
 		  AND category = $2
 		  AND is_official = TRUE
 		LIMIT 1
 	`, seed.Name, seed.Category).Scan(&templateID)

	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			return 0, fmt.Errorf("find template seed %q: %w", seed.Name, err)
		}

		err = tx.QueryRow(ctx, `
 			INSERT INTO templates (name, description, category, is_official, metadata)
 			VALUES ($1, $2, $3, $4, $5)
 			RETURNING id
 		`, seed.Name, seed.Description, seed.Category, seed.IsOfficial,
			metadataJSON).Scan(&templateID)
		if err != nil {
			return 0, fmt.Errorf("insert template seed %q: %w", seed.Name, err)
		}

		return templateID, nil
	}

	if _, err := tx.Exec(ctx, `
 		UPDATE templates
 		SET
 			description = $1,
 			is_official = $2,
 			metadata = $3
 		WHERE id = $4
 	`, seed.Description, seed.IsOfficial, metadataJSON, templateID); err != nil {
		return 0, fmt.Errorf("update template seed %q: %w", seed.Name, err)
	}

	return templateID, nil
}
