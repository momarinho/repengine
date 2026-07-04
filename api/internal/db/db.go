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

	pool, err := pgxpool.NewWithConfig(context.Background(), config)
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

// RunMigrations is now in migrations.go

func SeedNodeTypes(ctx context.Context) error {
	seedData := []struct {
		slug, name, description, icon string
		schema                        string
	}{
		{"exercise", "Exercise", "A single exercise node", "dumbbell",
			`{"exercise_name": "", "sets": 3, "reps": "", "rest_seconds": 90, "notes": ""}`},
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
				"week_1_reps": "5/5/5+",
				"week_1_intensity": "65/70/75",
				"week_1_rpe": "7/8/9",
				"week_2_reps": "3/3/3+",
				"week_2_intensity": "70/75/80",
				"week_2_rpe": "8/8/9",
				"week_3_reps": "5/3/1+",
				"week_3_intensity": "75/80/85",
				"week_3_rpe": "8/9/9",
				"week_4_reps": "5/5/5",
				"week_4_intensity": "40/50/60",
				"week_4_rpe": "6/6/6",
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
				"rest_seconds": 120,
				"fail_sequence": "",
				"reset_percent": 0.85,
				"rounding_precision": 2.5,
				"notes": ""
			}`,
		},
		{
			"superset",
			"Superset",
			"Alternating pull/push or multi-exercise group",
			"layers",
			`{
				"exercise_a_name": "",
				"exercise_b_name": "",
				"sets": 3,
				"reps_a": "5",
				"reps_b": "10",
				"progression_type_a": "linear",
				"progression_type_b": "none",
				"start_load_a": null,
				"start_load_b": null,
				"increment_a": 2.5,
				"increment_b": 0,
				"load_unit_a": "kg",
				"load_unit_b": "kg",
				"progression_rule_a": "add_each_session",
				"progression_rule_b": "manual",
				"rest_seconds": 120,
				"notes": ""
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
			"week_1_intensity": "65/70/75",
			"week_1_rpe":       "7/7/8",
			"week_2_reps":      "8/8/8",
			"week_2_intensity": "70/75/80",
			"week_2_rpe":       "7/8/8",
			"week_3_reps":      "5/5/5",
			"week_3_intensity": "75/80/85",
			"week_3_rpe":       "8/8/9",
			"week_4_reps":      "10/10/10",
			"week_4_intensity": "67.5/72.5/77.5",
			"week_4_rpe":       "7/7/8",
			"week_5_reps":      "8/8/8",
			"week_5_intensity": "72.5/77.5/82.5",
			"week_5_rpe":       "8/8/9",
			"week_6_reps":      "5/5/5",
			"week_6_intensity": "77.5/82.5/87.5",
			"week_6_rpe":       "8/9/9",
		},
	}
}

func fiveThreeOneWaveBlock(exercise string, restSeconds int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "wave",
		Data: map[string]any{
			"exercise_name":    exercise,
			"active_week":      1,
			"rest_seconds":     restSeconds,
			"week_1_reps":      "5/5/5+",
			"week_1_intensity": "65/70/75",
			"week_1_rpe":       "7/8/9",
			"week_2_reps":      "3/3/3+",
			"week_2_intensity": "70/75/80",
			"week_2_rpe":       "8/8/9",
			"week_3_reps":      "5/3/1+",
			"week_3_intensity": "75/80/85",
			"week_3_rpe":       "8/9/9",
			"week_4_reps":      "5/5/5",
			"week_4_intensity": "40/50/60",
			"week_4_rpe":       "6/6/6",
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

func supersetBlock(exA, exB, repsA, repsB string, sets, restSeconds int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "superset",
		Data: map[string]any{
			"exercise_a_name":    exA,
			"exercise_b_name":    exB,
			"sets":               sets,
			"reps_a":             repsA,
			"reps_b":             repsB,
			"progression_type_a": "none",
			"progression_type_b": "none",
			"rest_seconds":       restSeconds,
		},
	}
}

func hybridSupersetBlock(exA, exB, repsA, repsB string, sets int, progA, progB string, startLoadA, startLoadB float64, restSeconds int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "superset",
		Data: map[string]any{
			"exercise_a_name":    exA,
			"exercise_b_name":    exB,
			"sets":               sets,
			"reps_a":             repsA,
			"reps_b":             repsB,
			"progression_type_a": progA,
			"progression_type_b": progB,
			"start_load_a":       startLoadA,
			"start_load_b":       startLoadB,
			"increment_a":        2.5,
			"increment_b":        2.5,
			"load_unit_a":        "kg",
			"load_unit_b":        "kg",
			"progression_rule_a": "add_each_session",
			"progression_rule_b": "add_each_session",
			"rest_seconds":       restSeconds,
		},
	}
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

func gzclpT1Block(exercise string, startLoad float64, loadUnit string, increment float64, restSeconds int, notes string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "linear_progression",
		Data: map[string]any{
			"exercise_name":      exercise,
			"sets":               3,
			"reps":               "5",
			"start_load":         startLoad,
			"load_unit":          loadUnit,
			"increment":          increment,
			"progression_rule":   "add_each_session",
			"rest_seconds":       restSeconds,
			"fail_sequence":      "3x5 -> 5x3 -> 6x2",
			"reset_percent":      0.85,
			"rounding_precision": 2.5,
			"notes":              notes,
		},
	}
}

func linearProgressionBlockWithNotes(exercise, reps, loadUnit string, sets int, startLoad, increment float64, restSeconds int, notes string) templateBlockSeed {
	block := linearProgressionBlock(exercise, reps, loadUnit, sets, startLoad, increment, restSeconds)
	block.Data["notes"] = notes
	return block
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
			Name:        "Powerbuilding LP & Supersets",
			Description: "A structured 3-day split testing linear progression, standard supersets, timed mobility, and rest blocks.",
			Category:    "strength",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "6 weeks",
				"frequency": "3 days/week",
				"level":     "intermediate",
			},
			Blocks: []templateBlockSeed{
				sectionBlock("Day 1 - Upper Body Push", "Focusing on Barbell Bench Press and supersets.", "day"),
				linearProgressionBlock("Barbell Bench Press", "5", "kg", 3, 60.0, 2.5, 180),
				restBlock(120),
				supersetBlock("Barbell Overhead Press", "Lat Pulldown", "8", "10", 3, 90),
				restBlock(90),
				exerciseBlock("Triceps Pushdown", "12", 3),

				sectionBlock("Day 2 - Lower Body & Core", "Focusing on Squats, Romanian Deadlifts, and timed core finisher.", "day"),
				linearProgressionBlock("Back Squat", "5", "kg", 3, 80.0, 5.0, 180),
				restBlock(120),
				exerciseBlock("Romanian Deadlift", "8", 3),
				exerciseBlock("Hanging Leg Raise", "15", 3),
				timedExerciseBlock("Plank Hold", 60),
			},
		},
		{
			Name:        "Conjugate Method & Waves",
			Description: "An advanced full-body program combining multi-week wave progressions, hybrid supersets, and timed skill work.",
			Category:    "hybrid",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "4 weeks",
				"frequency": "4 days/week",
				"level":     "advanced",
			},
			Blocks: []templateBlockSeed{
				sectionBlock("Day 1 - Max Effort Pull", "Heavy deadlift wave loading and loaded pull-up supersets.", "day"),
				templateBlockSeed{
					NodeTypeSlug: "wave",
					Data: map[string]any{
						"exercise_name":    "Deadlift",
						"active_week":      1,
						"rest_seconds":     180,
						"week_1_reps":      "5/5/5+",
						"week_1_intensity": "65/70/75",
						"week_1_rpe":       "7/8/9",
						"week_2_reps":      "3/3/3+",
						"week_2_intensity": "70/75/80",
						"week_2_rpe":       "8/8/9",
						"week_3_reps":      "5/3/1+",
						"week_3_intensity": "75/80/85",
						"week_3_rpe":       "8/9/9",
						"week_4_reps":      "5/5/5",
						"week_4_intensity": "40/50/60",
						"week_4_rpe":       "6/6/6",
					},
				},
				restBlock(120),
				hybridSupersetBlock("Weighted Pull-Up", "Ring Dips", "5", "8", 4, "linear", "none", 10.0, 0.0, 120),
				timedExerciseBlock("Crow Pose Practice", 300),

				sectionBlock("Day 2 - Rest & Mobility", "Active recovery focusing on wrists, shoulders, and hips.", "day"),
				timedExerciseBlock("Wrist & Shoulder Mobility", 480),
			},
		},
		{
			Name:        "3-Day Hybrid Hypertrophy GZCLP",
			Description: "Customized 3-day split using weighted bodyweight T1 progressions, unilateral leg focus, and high-volume T2 builders.",
			Category:    "hybrid",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "8 weeks",
				"frequency": "3 days/week",
				"level":     "advanced",
			},
			Blocks: []templateBlockSeed{
				sectionBlock("Day 1: Heavy Push & Posterior Chain", "Focusing on weighted dips, hamstrings stretch, and high-volume pull-ups.", "day"),
				gzclpT1Block("Weighted Ring Dips", 10.0, "kg", 2.0, 180, "Use your dip belt. Load heavily to drive chest and tricep tension."),
				restBlock(120),
				linearProgressionBlockWithNotes("Barbell Romanian Deadlift", "10", "kg", 3, 40.0, 2.5, 120, "Controlled Romanian Deadlift with a 3-second eccentric phase focusing on hamstring stretch."),
				restBlock(90),
				exerciseBlockWithNotes("Bodyweight Pull-Up", "AMRAP", 3, "Accumulate volume for lat width, keeping 1-2 reps in reserve."),
				restBlock(90),
				exerciseBlock("Ring Tricep Extension", "15+", 3),
				exerciseBlock("Hanging Toes-to-Rings", "12-15", 3),

				sectionBlock("Day 2: Heavy Quads & Shoulder Mass", "Focusing on unilateral squats, high-volume OHP, and back work.", "day"),
				gzclpT1Block("Barbell Bulgarian Split Squat", 20.0, "kg", 2.5, 180, "Clean bar, press overhead, rest on back. Functions like a 100kg bilateral squat."),
				restBlock(120),
				linearProgressionBlockWithNotes("Barbell Overhead Press", "8-10", "kg", 3, 40.0, 2.5, 120, "Higher rep range close to failure for shoulder mass."),
				restBlock(90),
				exerciseBlockWithNotes("Ring Inverted Row", "10-12", 3, "Elevate feet parallel to the floor. Focus on squeezing shoulder blades."),
				restBlock(90),
				exerciseBlock("Ring Face Pull", "15+", 3),
				exerciseBlock("Ring Rollout", "AMRAP", 3),

				sectionBlock("Day 3: Heavy Pull & Quad Volume", "Focusing on weighted pull-ups, front/Zercher squats, and chest stretch.", "day"),
				gzclpT1Block("Weighted Pull-Up", 10.0, "kg", 2.0, 180, "Strap plates to waist. Progressively add weight weekly."),
				restBlock(120),
				linearProgressionBlockWithNotes("Barbell Zercher Squat", "10-12", "kg", 3, 40.0, 2.5, 120, "Hold in elbow crooks or front rack to target quads and core deeply."),
				restBlock(90),
				exerciseBlockWithNotes("Deficit Ring Push-Up", "10-12", 3, "Lower rings close to floor. Instability creates deep chest stretch."),
				restBlock(90),
				exerciseBlock("Ring Bicep Curl", "15+", 3),
				timedExerciseBlock("Pallof Press or RKC Plank Hold", 45),
			},
		},
	}

	tx, err := Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin template seed tx: %w", err)
	}
	defer tx.Rollback(ctx)

	// Clean up existing official templates first to ensure we start fresh
	if _, err := tx.Exec(ctx, `DELETE FROM templates WHERE is_official = TRUE`); err != nil {
		return fmt.Errorf("clear existing official templates: %w", err)
	}

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
