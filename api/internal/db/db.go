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
		{"exercise", "Exercise", "A single exercise node", "dumbbell",
			`{"exercise_name": "", "sets": 3, "reps": "", "rest_seconds": 90}`},
		{"exercise_timed", "Timed Exercise", "Exercise with duration", "timer",
			`{"exercise_name": "", "duration": 30}`},
		{
			"wave",
			"Wave",
			"Progressive exercise block with set-by-set intensities and week presets",
			"activity",
			`{
				"exercise_name": "",
				"active_week": 1,
				"rest_seconds": 120,
				"week_1_reps": "",
				"week_1_intensity": "",
				"week_1_rpe": "",
				"week_2_reps": "",
				"week_2_intensity": "",
				"week_2_rpe": "",
				"week_3_reps": "",
				"week_3_intensity": "",
				"week_3_rpe": "",
				"week_4_reps": "",
				"week_4_intensity": "",
				"week_4_rpe": "",
				"week_5_reps": "",
				"week_5_intensity": "",
				"week_5_rpe": "",
				"week_6_reps": "",
				"week_6_intensity": "",
				"week_6_rpe": ""
			}`,
		},
		{
			"linear_progression",
			"Linear Progression",
			"Session-to-session load progression",
			"trending_up",
			`{
				"exercise_name": "",
				"sets": 3,
				"reps": "5",
				"start_load": null,
				"load_unit": "kg",
				"increment": 2.5,
				"progression_rule": "add_each_session",
				"rest_seconds": 120
			}`,
		},
		{"repeat", "Repeat", "Repeat block", "repeat", `{"times": 3}`},
		{"rest", "Rest", "Rest period between sets", "pause", `{"duration": 30}`},
		{"section", "Section", "Logical section or training day divider", "folder",
			`{
				"title": "Day 1",
				"subtitle": "",
				"kind": "day",
				"collapsed": false
			}`},
	}

	for _, n := range seedData {
		_, err := Pool.Exec(ctx,
			`INSERT INTO node_types (slug, name, description, icon, schema)
               VALUES ($1, $2, $3, $4, $5)
               ON CONFLICT (slug) DO UPDATE
               SET
                 name = EXCLUDED.name,
                 description = EXCLUDED.description,
                 icon = EXCLUDED.icon,
                 schema = EXCLUDED.schema`,
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

func sectionBlock(title, subtitle, kind string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "section",
		Data: map[string]any{
			"title":     title,
			"subtitle":  subtitle,
			"kind":      kind,
			"collapsed": false,
		},
	}
}

func hybridWaveBlock(exercise string, restSeconds int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "wave",
		Data: map[string]any{
			"exercise_name":    exercise,
			"active_week":      1,
			"rest_seconds":     restSeconds,
			"week_1_reps":      "10/10/10",
			"week_1_intensity": "65/65/65",
			"week_1_rpe":       "7/7/7",
			"week_2_reps":      "8/8/8",
			"week_2_intensity": "75/75/75",
			"week_2_rpe":       "8/8/8",
			"week_3_reps":      "5/5/5",
			"week_3_intensity": "85/85/85",
			"week_3_rpe":       "9/9/9",
			"week_4_reps":      "10/10/10",
			"week_4_intensity": "70/70/70",
			"week_4_rpe":       "7/7/7",
			"week_5_reps":      "8/8/8",
			"week_5_intensity": "80/80/80",
			"week_5_rpe":       "8/8/8",
			"week_6_reps":      "5/5/5",
			"week_6_intensity": "90/90/90",
			"week_6_rpe":       "9/9/10",
		},
	}
}

func exerciseBlock(exercise, reps string, sets int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          sets,
			"reps":          reps,
		},
	}
}

func exerciseBlockWithNotes(exercise, reps string, sets int, notes string) templateBlockSeed {
	block := exerciseBlock(exercise, reps, sets)
	block.Data["notes"] = notes
	return block
}

func timedExerciseBlock(exercise string, duration int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise_timed",
		Data: map[string]any{
			"exercise_name": exercise,
			"duration":      duration,
		},
	}
}

func linearProgressionBlock(exercise, reps, loadUnit string, sets int, startLoad, increment float64, restSeconds int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "linear_progression",
		Data: map[string]any{
			"exercise_name":    exercise,
			"sets":             sets,
			"reps":             reps,
			"start_load":       startLoad,
			"load_unit":        loadUnit,
			"increment":        increment,
			"progression_rule": "add_each_session",
			"rest_seconds":     restSeconds,
		},
	}
}

func restBlock(duration int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "rest",
		Data: map[string]any{
			"duration": duration,
		},
	}
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
						"title":     "Day 1 - Squat",
						"subtitle":  "Main lower-body strength day",
						"kind":      "day",
						"collapsed": false,
					},
				},
				{
					NodeTypeSlug: "wave",
					Data: map[string]any{
						"exercise_name":    "Squat",
						"active_week":      1,
						"rest_seconds":     120,
						"week_1_reps":      "5/5/5+",
						"week_1_intensity": "65/75/85",
						"week_1_rpe":       "8/8/9",
						"week_2_reps":      "3/3/3+",
						"week_2_intensity": "70/80/90",
						"week_2_rpe":       "8/8/9",
						"week_3_reps":      "5/3/1+",
						"week_3_intensity": "75/85/95",
						"week_3_rpe":       "8/9/9",
						"week_4_reps":      "5/5/5",
						"week_4_intensity": "40/50/60",
						"week_4_rpe":       "6/6/6",
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
						"title":     "Day 2 - Bench Press",
						"subtitle":  "Main upper-body strength day",
						"kind":      "day",
						"collapsed": false,
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
						"title":     "Day 1 - T1 Main Lift",
						"subtitle":  "Primary lift progression",
						"kind":      "day",
						"collapsed": false,
					},
				},
				{
					NodeTypeSlug: "linear_progression",
					Data: map[string]any{
						"exercise_name":    "Squat",
						"sets":             5,
						"reps":             "3",
						"start_load":       45,
						"load_unit":        "lb",
						"increment":        5,
						"progression_rule": "add_each_session",
						"rest_seconds":     180,
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
						"title":     "T2 Secondary Lift",
						"subtitle":  "Supplemental strength volume",
						"kind":      "section",
						"collapsed": false,
					},
				},
				{
					NodeTypeSlug: "linear_progression",
					Data: map[string]any{
						"exercise_name":    "Bench Press",
						"sets":             3,
						"reps":             "10",
						"start_load":       45,
						"load_unit":        "lb",
						"increment":        5,
						"progression_rule": "add_each_session",
						"rest_seconds":     120,
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
						"title":     "T3 Accessories",
						"subtitle":  "Higher-rep accessory work",
						"kind":      "section",
						"collapsed": false,
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
		{
			Name:        "Hybrid Calisthenics + Weights",
			Description: "Wave progression plan combining weighted compounds with calisthenics rep and skill progressions.",
			Category:    "hybrid",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "6 weeks + 1 deload week",
				"frequency": "4 days/week",
				"level":     "intermediate",
				"mesocycle": "6 weeks, then 1 deload week",
				"schedule":  "Mon Upper Push, Tue Lower Body, Thu Upper Pull, Fri Lower Power",
				"skill_goals": []string{
					"Crow Pose",
					"Front Lever",
					"Handstand Push-Up",
					"Pistol Squat",
				},
			},
			Blocks: []templateBlockSeed{
				sectionBlock("Day 1 - Upper Push", "Monday. Wave-loaded pressing plus push-up and crow pose progressions.", "day"),
				hybridWaveBlock("Barbell Overhead Press", 180),
				restBlock(120),
				hybridWaveBlock("Weighted Ring Dips", 180),
				restBlock(90),
				exerciseBlockWithNotes("Push-Up Variation", "AMRAP", 3, "Advance variant at 20 clean reps. Ladder: Standard -> Archer -> Ring Push-Up -> Weighted -> Pseudo Planche."),
				timedExerciseBlock("Crow Pose Practice", 600),

				sectionBlock("Day 2 - Lower Body", "Tuesday. Squat wave loading with hinge progression and lower-body skill work.", "day"),
				hybridWaveBlock("Back Squat", 180),
				restBlock(120),
				linearProgressionBlock("Romanian Deadlift", "8-10", "kg", 3, 60, 2.5, 120),
				restBlock(90),
				exerciseBlockWithNotes("Pistol Squat Progression", "5/leg", 3, "Advance variation weekly. Ladder: Assisted band/TRX -> Box Pistol -> Full Pistol -> Weighted Pistol."),
				exerciseBlockWithNotes("Nordic Hamstring Curl", "6", 3, "Eccentric focus with 5-second negative."),

				sectionBlock("Day 3 - Rest / Mobility", "Wednesday. Active recovery for wrists, hips, hamstrings, and thoracic spine.", "day"),
				timedExerciseBlock("Wrist Prep + Wrist Circles", 300),
				timedExerciseBlock("Hip Flexor + Hamstring Stretch", 480),
				timedExerciseBlock("Thoracic Spine Mobility", 300),

				sectionBlock("Day 4 - Upper Pull", "Thursday. Pull-up wave loading with horizontal pulling and front lever skill work.", "day"),
				hybridWaveBlock("Weighted Pull-Up", 180),
				restBlock(120),
				linearProgressionBlock("Barbell / Dumbbell Row", "8-10", "kg", 3, 40, 2.5, 120),
				restBlock(90),
				exerciseBlock("Ring Rows", "12-15", 3),
				timedExerciseBlock("Front Lever Progression", 480),

				sectionBlock("Day 5 - Lower Power + Posterior Chain", "Friday. Deadlift wave loading with unilateral strength and hamstring control.", "day"),
				hybridWaveBlock("Deadlift", 210),
				restBlock(150),
				linearProgressionBlock("Bulgarian Split Squat", "8-10/leg", "kg", 3, 20, 2.5, 120),
				restBlock(90),
				exerciseBlockWithNotes("Nordic Hamstring Curl", "6", 3, "Eccentric focus with 5-second negative."),

				sectionBlock("Key Principles", "Use fixed sets, protect skill quality, and deload every 7th week.", "section"),
				exerciseBlockWithNotes("Wave Loading Rules", "Fixed sets", 1, "Wave load only primary compounds: OHP, Ring Dips, Back Squat, Pull-Ups, Deadlift. Weeks 1-6 use 65/75/85 -> 70/80/90%. Week 7 deloads at 50-60%."),
				exerciseBlockWithNotes("Calisthenics Skill Rules", "Technical quality", 1, "Stop crow pose, pistol, and front lever work when form breaks. No grinding skill reps."),
				exerciseBlockWithNotes("Push-Up Finisher Principle", "Hypertrophy", 1, "After ring dips, use push-up variation as hypertrophy work without adding another heavy press."),
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
