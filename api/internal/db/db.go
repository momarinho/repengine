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
				"rest_seconds": 120
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
					Data:         fiveThreeOneWaveBlock("Squat", 120).Data,
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
				fiveThreeOneWaveBlock("Bench Press", 120),
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
				exerciseBlockWithNotes("Wave Loading Rules", "Fixed sets", 1, "Wave load only primary compounds: OHP, Ring Dips, Back Squat, Pull-Ups, Deadlift. Each week climbs set by set, e.g. 65/70/75 -> 70/75/80 -> 75/80/85, then repeats slightly heavier before the deload."),
				exerciseBlockWithNotes("Calisthenics Skill Rules", "Technical quality", 1, "Stop crow pose, pistol, and front lever work when form breaks. No grinding skill reps."),
				exerciseBlockWithNotes("Push-Up Finisher Principle", "Hypertrophy", 1, "After ring dips, use push-up variation as hypertrophy work without adding another heavy press."),
			},
		},
		{
			Name:        "Upper/Lower (Pull & Dip Focus)",
			Description: "An Upper/Lower split program focusing on Weighted Pull-Ups (Day 1) and Weighted Dips (Day 3) as main weighted compound exercises in a native Pull/Push superset fashion, followed by Abs and Arms, with a repeating Lower day structure featuring Deadlifts.",
			Category:    "hypertrophy",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "8 weeks",
				"frequency": "4 days/week",
				"level":     "intermediate",
			},
			Blocks: []templateBlockSeed{
				sectionBlock("Day 1 - Upper (Pull Focus / Supersets)", "Weighted pull-up main lift, alternating pull + push supersets, abs, and arms.", "day"),
				hybridSupersetBlock("Weighted Pull-Up", "Dumbbell Bench Press", "5", "8-10", 4, "linear", "none", 10.0, 0.0, 120),
				hybridSupersetBlock("Barbell Row", "Incline Dumbbell Fly", "8-10", "10-12", 3, "linear", "none", 50.0, 0.0, 90),
				exerciseBlock("Hanging Leg Raise (Abs)", "12-15", 3),
				restBlock(60),
				exerciseBlock("Bicep Curl (Arms)", "10-12", 3),

				sectionBlock("Day 2 - Lower (Squat Focus)", "Squat progression with posterior chain accessories.", "day"),
				linearProgressionBlock("Back Squat", "6-8", "kg", 4, 60, 2.5, 180),
				restBlock(180),
				linearProgressionBlock("Romanian Deadlift", "8-10", "kg", 3, 60, 2.5, 120),
				restBlock(120),
				exerciseBlock("Leg Press", "10-12", 3),
				restBlock(90),
				exerciseBlock("Standing Calf Raise", "12-15", 4),

				sectionBlock("Day 3 - Upper (Dip Focus / Supersets)", "Weighted dip main lift, alternating pull + push supersets, abs, and arms.", "day"),
				hybridSupersetBlock("Lat Pulldown", "Weighted Dip", "8-10", "5", 4, "none", "linear", 0.0, 15.0, 120),
				supersetBlock("Chest-Supported Row", "Dumbbell Overhead Press", "10-12", "8-10", 3, 90),
				exerciseBlock("Cable Crunch (Abs)", "12-15", 3),
				restBlock(60),
				exerciseBlock("Lateral Raise (Arms)", "12-15", 3),

				sectionBlock("Day 4 - Lower (Deadlift Focus)", "Deadlift main lift with repeating squat and leg accessories.", "day"),
				linearProgressionBlock("Deadlift", "5", "kg", 3, 80, 5.0, 210),
				restBlock(210),
				linearProgressionBlock("Back Squat", "8-10", "kg", 3, 50, 2.5, 150),
				restBlock(150),
				exerciseBlock("Leg Press", "12-15", 3),
				restBlock(90),
				exerciseBlock("Standing Calf Raise", "12-15", 4),
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
