package db

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"regexp"
	"strconv"
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

	var pool *pgxpool.Pool
	var lastErr error
	maxRetries := 10

	for i := 1; i <= maxRetries; i++ {
		pool, err = pgxpool.NewWithConfig(context.Background(), config)
		if err == nil {
			pingCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			lastErr = pool.Ping(pingCtx)
			cancel()

			if lastErr == nil {
				Pool = pool
				return nil
			}
			pool.Close()
		} else {
			lastErr = err
		}

		if i < maxRetries {
			slog.Warn("database connection attempt failed, retrying...", "attempt", i, "max_retries", maxRetries, "err", lastErr)
			time.Sleep(2 * time.Second)
		}
	}

	return fmt.Errorf("ping after %d attempts: %w", maxRetries, lastErr)
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
			`{"exercise_name": "", "sets": 3, "reps": "", "rest_seconds": 90, "notes": "", "load_value": null, "load_unit": "kg", "progression": null, "load": null, "target_load": null}`},
		{"exercise_timed", "Timed Exercise", "Exercise with duration", "timer",
			`{"exercise_name": "", "duration": 30, "progression": null}`},
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
				"week_6_rpe": "",
				"week": "",
				"intensity_percent": "",
				"rpe": "",
				"reps": ""
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
				"reps": "5+",
				"start_load": null,
				"load_unit": "kg",
				"increment": 2.5,
				"progression_rule": "gzclp_standard_t1",
				"rest_seconds": 180,
				"fail_sequence": "3x5+ -> 5x3+ -> 6x2+",
				"reset_percent": 0.85,
				"rounding_precision": 2.5,
				"notes": "",
				"deload_weeks": null,
				"deload_percent": null,
				"progression": null,
				"load": null,
				"load_value": null,
				"target_load": null
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
				"reps_a": "5-8",
				"reps_b": "5-8",
				"progression_type_a": "none",
				"progression_type_b": "none",
				"start_load_a": null,
				"start_load_b": null,
				"increment_a": 2.5,
				"increment_b": 2.5,
				"load_unit_a": "kg",
				"load_unit_b": "kg",
				"min_reps_a": 5,
				"max_reps_a": 8,
				"min_reps_b": 5,
				"max_reps_b": 8,
				"progression_rule_a": "add_each_session",
				"progression_rule_b": "add_each_session",
				"rest_seconds": 120,
				"notes": "",
				"load_value_a": null,
				"load_value_b": null,
				"load_a": null,
				"load_b": null,
				"target_load_a": null,
				"target_load_b": null
			}`,
		},
		{
			"repeat",
			"Repeat",
			"Repeat block",
			"repeat",
			`{
				"title": "",
				"times": 3,
				"rounds": 3,
				"reps": "",
				"interval_phases": []
			}`,
		},
		{"rest", "Rest", "Rest period between sets", "pause", `{"duration": 30}`},
		{"section", "Section", "Logical section or training day divider", "folder",
			`{
				"title": "Day 1",
				"subtitle": "",
				"kind": "day",
				"collapsed": false,
				"label": ""
			}`},
		{
			"deload",
			"Deload & Recovery",
			"Configures scheduled active recovery or deload parameters for routine blocks",
			"battery_charging_full",
			`{
				"title": "Deload & Recovery Protocol",
				"frequency_weeks": 4,
				"strategy": "volume",
				"volume_reduction_percent": 40,
				"intensity_reduction_percent": 15,
				"target_rir": 3,
				"notes": "Reduce fatigue and promote joint recovery. Cap sets and stop well before failure.",
				"is_active": false
			}`,
		},
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
			"rest_seconds":  90,
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

func repeatBlock(title string, rounds int, reps string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "repeat",
		Data: map[string]any{
			"title":  title,
			"times":  rounds,
			"rounds": rounds,
			"reps":   reps,
		},
	}
}

func intervalRepeatBlock(title string, rounds int, reps string, phases []map[string]any) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "repeat",
		Data: map[string]any{
			"title":           title,
			"times":           rounds,
			"rounds":          rounds,
			"reps":            reps,
			"interval_phases": phases,
		},
	}
}


var digitPattern = regexp.MustCompile(`\d+`)

func parseRepsMinMax(reps string) (int, int) {
	matches := digitPattern.FindAllString(reps, -1)
	if len(matches) == 0 {
		return 8, 12
	}
	first, _ := strconv.Atoi(matches[0])
	if len(matches) == 1 {
		return first, first
	}
	last, _ := strconv.Atoi(matches[len(matches)-1])
	if last < first {
		last = first
	}
	return first, last
}

func calisthenicsDoubleProgressionBlock(exercise, reps string, sets int, restSeconds int, notes string) templateBlockSeed {
	minReps, maxReps := parseRepsMinMax(reps)
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          sets,
			"reps":          reps,
			"load_value":    0.0,
			"load_unit":     "kg",
			"rest_seconds":  restSeconds,
			"notes":         notes,
			"progression": map[string]any{
				"type":      "double",
				"min_reps":  minReps,
				"max_reps":  maxReps,
				"increment": 2.5,
			},
		},
	}
}

func calisthenicsStepProgressionBlock(exercise, reps, sequence string, restSeconds int, notes string) templateBlockSeed {
	minReps, maxReps := parseRepsMinMax(reps)
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          3,
			"reps":          reps,
			"load_value":    0.0,
			"load_unit":     "kg",
			"rest_seconds":  restSeconds,
			"notes":         notes,
			"progression": map[string]any{
				"type":          "double",
				"min_reps":      minReps,
				"max_reps":      maxReps,
				"increment":     2.5,
				"fail_sequence": sequence,
			},
		},
	}
}

func calisthenicsSupersetBlock(exA, exB, repsA, repsB string, sets, restSeconds int, notes string) templateBlockSeed {
	minA, maxA := parseRepsMinMax(repsA)
	minB, maxB := parseRepsMinMax(repsB)
	return templateBlockSeed{
		NodeTypeSlug: "superset",
		Data: map[string]any{
			"exercise_a_name":    exA,
			"exercise_b_name":    exB,
			"sets":               sets,
			"reps_a":             repsA,
			"reps_b":             repsB,
			"progression_type_a": "double",
			"progression_type_b": "double",
			"start_load_a":       0.0,
			"start_load_b":       0.0,
			"increment_a":        2.5,
			"increment_b":        2.5,
			"load_unit_a":        "kg",
			"load_unit_b":        "kg",
			"min_reps_a":         minA,
			"max_reps_a":         maxA,
			"min_reps_b":         minB,
			"max_reps_b":         maxB,
			"rest_seconds":       restSeconds,
			"notes":              notes,
		},
	}
}

func linearProgressionBlock(exercise, reps, loadUnit string, sets int, startLoad, increment float64, restSeconds int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          sets,
			"reps":          reps,
			"load_value":    startLoad,
			"load_unit":     loadUnit,
			"rest_seconds":  restSeconds,
			"notes":         "",
			"progression": map[string]any{
				"type":      "linear",
				"increment": increment,
				"rule":      "add_each_session",
			},
		},
	}
}

func gzclpT1Block(exercise string, startLoad float64, loadUnit string, increment float64, restSeconds int, notes string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          3,
			"reps":          "5+",
			"load_value":    startLoad,
			"load_unit":     loadUnit,
			"rest_seconds":  restSeconds,
			"notes":         notes,
			"progression": map[string]any{
				"type":               "linear",
				"rule":               "gzclp_standard_t1",
				"increment":          increment,
				"fail_sequence":      "3x5+ -> 5x3+ -> 6x2+",
				"bounce_to_base":     false,
				"reset_percent":      0.85,
				"rounding_precision": 2.5,
			},
		},
	}
}

func gzclpT2Block(exercise string, startLoad float64, loadUnit string, increment float64, restSeconds int, notes string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          3,
			"reps":          "10",
			"load_value":    startLoad,
			"load_unit":     loadUnit,
			"rest_seconds":  restSeconds,
			"notes":         notes,
			"progression": map[string]any{
				"type":               "linear",
				"rule":               "gzclp_standard_t2",
				"increment":          increment,
				"fail_sequence":      "3x10 -> 3x8 -> 3x6",
				"bounce_to_base":     false,
				"reset_percent":      0.85,
				"rounding_precision": 2.5,
			},
		},
	}
}

func gzclpT3Block(exercise string, startLoad float64, loadUnit string, increment float64, restSeconds int, notes string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          3,
			"reps":          "15+",
			"load_value":    startLoad,
			"load_unit":     loadUnit,
			"rest_seconds":  restSeconds,
			"notes":         notes,
			"progression": map[string]any{
				"type":           "linear",
				"rule":           "gzclp_standard_t3",
				"increment":      increment,
				"min_amrap_reps": 25,
			},
		},
	}
}

func gzclpHypertrophyT1Block(exercise string, startLoad float64, loadUnit string, increment float64, restSeconds int, notes string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          5,
			"reps":          "3+",
			"load_value":    startLoad,
			"load_unit":     loadUnit,
			"rest_seconds":  restSeconds,
			"notes":         notes,
			"progression": map[string]any{
				"type":               "linear",
				"rule":               "gzclp_hypertrophy_t1",
				"increment":          increment,
				"fail_sequence":      "5x3+ -> 6x2+",
				"bounce_to_base":     true,
				"reset_percent":      0.85,
				"rounding_precision": 2.5,
			},
		},
	}
}

func gzclpHypertrophyT2Block(exercise string, startLoad float64, loadUnit string, increment float64, restSeconds int, notes string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          3,
			"reps":          "10",
			"load_value":    startLoad,
			"load_unit":     loadUnit,
			"rest_seconds":  restSeconds,
			"notes":         notes,
			"progression": map[string]any{
				"type":               "linear",
				"rule":               "gzclp_hypertrophy_t2",
				"increment":          increment,
				"fail_sequence":      "3x10 -> 3x8 -> 3x6",
				"bounce_to_base":     true,
				"reset_percent":      0.85,
				"rounding_precision": 2.5,
			},
		},
	}
}

func gzclpHypertrophyT3Block(exercise string, reps string, sets int, startLoad float64, loadUnit string, increment float64, restSeconds int, notes string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          sets,
			"reps":          reps,
			"load_value":    startLoad,
			"load_unit":     loadUnit,
			"rest_seconds":  restSeconds,
			"notes":         notes,
			"progression": map[string]any{
				"type":              "linear",
				"rule":              "gzclp_hypertrophy_t3",
				"increment":         increment,
				"min_amrap_reps":    20,
				"min_total_reps":    50,
				"strict_total_reps": true,
			},
		},
	}
}

func wendler531WaveBlock(exercise string, restSeconds int) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "wave",
		Data: map[string]any{
			"exercise_name":    exercise,
			"active_week":      1,
			"rest_seconds":     restSeconds,
			"notes":            "Jim Wendler 5/3/1 Wave (Percentages of Training Max). Week 1: 3x5+ (65/75/85%). Week 2: 3x3+ (70/80/90%). Week 3: 5/3/1+ (75/85/95%). Week 4: Deload 3x5 (40/50/60%).",
			"week_1_reps":      "5/5/5+",
			"week_1_intensity": "65/75/85",
			"week_1_rpe":       "7/8/9",
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

func doubleProgressionBlock(exercise, reps string, sets int, targetLoad, increment float64, restSeconds int, notes string) templateBlockSeed {
	minReps, maxReps := parseRepsMinMax(reps)
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          sets,
			"reps":          reps,
			"load_value":    targetLoad,
			"load_unit":     "kg",
			"rest_seconds":  restSeconds,
			"notes":         notes,
			"progression": map[string]any{
				"type":      "double",
				"min_reps":  minReps,
				"max_reps":  maxReps,
				"increment": increment,
			},
		},
	}
}

func cardioBlock(exercise, duration, notes string) templateBlockSeed {
	return templateBlockSeed{
		NodeTypeSlug: "exercise",
		Data: map[string]any{
			"exercise_name": exercise,
			"sets":          1,
			"reps":          duration,
			"load_value":    0.0,
			"load_unit":     "kg",
			"rest_seconds":  0,
			"notes":         notes,
			"progression": map[string]any{
				"type": "none",
			},
		},
	}
}


func recommendedRoutineDayBlocks(dayNum int) []templateBlockSeed {
	return []templateBlockSeed{
		sectionBlock(
			fmt.Sprintf("Day %d - Full Body (Recommended Routine)", dayNum),
			"Pairs: Pull-Up + Squat, Dip + Hinge, Row + Push-Up, followed by functional core triplet.",
			"day",
		),
		timedExerciseBlock("Dynamic Warm-up & Joint Prep", 300),
		calisthenicsSupersetBlock(
			"Pull-Up Progression",
			"Squat Progression",
			"5-8",
			"5-8",
			3,
			90,
			"Pair 1: Pull-up progression (Arch Hangs -> Negatives -> Strict Pull-up) paired with Squats (Bodyweight -> Bulgarian Split Squat -> Pistol). Double progression (3x5-8). 90s rest between alternating sets.",
		),
		restBlock(90),
		calisthenicsSupersetBlock(
			"Dip Progression",
			"Hinge Progression",
			"5-8",
			"5-8",
			3,
			90,
			"Pair 2: Dip progression (Parallel Bar Support -> Negative Dip -> Dip) paired with Hinge progression (Single-Leg RDL -> Banded Nordic Curl). Double progression (3x5-8). 90s rest between alternating sets.",
		),
		restBlock(90),
		calisthenicsSupersetBlock(
			"Inverted Row Progression",
			"Push-Up Progression",
			"5-8",
			"5-8",
			3,
			90,
			"Pair 3: Inverted Row progression (Incline Row -> Horizontal Row -> Ring Row) paired with Push-up progression (Standard -> Diamond -> Pseudo Planche). Double progression (3x5-8). 90s rest between alternating sets.",
		),
		restBlock(90),
		calisthenicsDoubleProgressionBlock(
			"Anti-Extension (Ring Rollout / Plank)",
			"8-12",
			3,
			60,
			"Core Triplet 1: Posterior pelvic tilt, lock ribs to pelvis. Progress from Plank to Ring/Ab Wheel Rollouts. 60s rest.",
		),
		calisthenicsDoubleProgressionBlock(
			"Anti-Rotation (Pallof Press / Band Rotation)",
			"8-12",
			3,
			60,
			"Core Triplet 2: Resist trunk rotation against band or cable tension. 60s rest.",
		),
		calisthenicsDoubleProgressionBlock(
			"Extension (Reverse Hyperextension / Arch Body)",
			"8-12",
			3,
			60,
			"Core Triplet 3: Squeeze glutes and lower back at top peak contraction. 60s rest before next round.",
		),
	}
}

func SeedTemplates(ctx context.Context) error {
	seeds := []templateSeed{
		{
			Name:        "Beginner 3-Day Physique & Functional Core Routine",
			Description: "A beginner-friendly 3-day split engineered for balanced hypertrophy, progressive core development (top-down, bottom-up, and anti-extension), and waist control.",
			Category:    "hypertrophy",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "8 weeks",
				"frequency": "3 days/week",
				"level":     "beginner",
			},
			Blocks: []templateBlockSeed{
				// Day 1
				sectionBlock("Day 1 - Quads, Glutes, Push & Upper Ab Flexion", "Squats, Hip Thrusts, Upper Body Press, Cable Crunch & Cardio", "day"),
				doubleProgressionBlock("Smith Machine Squat", "8-10", 3, 30.0, 2.5, 90, "Feet slightly forward on the platform, lower under control to parallel. RIR 2."),
				doubleProgressionBlock("Machine Hip Thrust", "8-10", 3, 40.0, 5.0, 90, "Drive through heels, pause 1 second at the top, keep chin tucked."),
				doubleProgressionBlock("Incline Chest Press Machine", "10-12", 3, 20.0, 2.5, 60, "Smooth pressing path, keep shoulders packed against the back pad."),
				doubleProgressionBlock("Cable Triceps Pushdown (Rope or Bar)", "10-12", 3, 15.0, 1.25, 60, "Keep upper arms glued to torso; fully extend at the bottom."),
				doubleProgressionBlock("Kneeling Cable Crunch", "10-12", 3, 20.0, 2.5, 60, "Keep hips locked in place; curl ribcage down toward pelvis, exhaling fully at peak contraction."),
				cardioBlock("Incline Treadmill Walk (Zone 2)", "10-15 min", "Incline 8-12%, speed 4.0-4.8 km/h. Easy conversational pace."),

				// Day 2
				sectionBlock("Day 2 - Posterior Chain, Pull & Lower Ab Control", "RDL, Lat Pulldown, Row, Hamstrings, Captain's Chair & Cardio", "day"),
				doubleProgressionBlock("Dumbbell Romanian Deadlift", "8-10", 3, 12.0, 2.0, 90, "Push hips straight back until hamstrings stretch; keep weights close to shins."),
				doubleProgressionBlock("Lat Pulldown Machine", "10-12", 3, 25.0, 2.5, 60, "Slight torso lean; drive elbows down toward the hips."),
				doubleProgressionBlock("Seated Cable Row", "10-12", 3, 25.0, 2.5, 60, "Sit tall, pull handle into belly button while squeezing shoulder blades."),
				doubleProgressionBlock("Lying or Seated Leg Curl Machine", "10-12", 3, 20.0, 2.5, 60, "Controlled 2-second lowering phase on every rep."),
				doubleProgressionBlock("Dumbbell Biceps Curl", "10-12", 3, 6.0, 1.0, 60, "Keep elbows fixed under shoulders without swinging the torso."),
				doubleProgressionBlock("Captain's Chair Knee Raise", "10-12", 3, 0.0, 0.0, 60, "Press forearms down into pads; curl pelvis up toward ribs at the top, avoiding momentum."),
				cardioBlock("Elliptical or Incline Walk (Zone 2)", "10-15 min", "Low-impact steady-state cardiovascular work."),

				// Day 3
				sectionBlock("Day 3 - Glute/Leg Isolation, Shoulders & Deep Core Bracing", "Abduction, Extensions, Lateral Raises, Face Pulls, Dead Bug & Cardio", "day"),
				doubleProgressionBlock("Seated Hip Abduction Machine", "15-20", 3, 30.0, 2.5, 30, "Sit upright or lean slightly forward; pause for 1 second at full open abduction."),
				doubleProgressionBlock("Leg Extension Machine", "12-15", 3, 25.0, 2.5, 45, "Smooth extension, controlled descent without letting weight stack slam."),
				doubleProgressionBlock("Dumbbell Lateral Raise", "12-15", 3, 4.0, 1.0, 30, "Raise arms slightly forward in the scapular plane, leading gently with elbows."),
				doubleProgressionBlock("Cable Face Pull", "12-15", 3, 12.5, 1.25, 45, "Pull rope toward forehead while rotating knuckles backward for posture reinforcement."),
				doubleProgressionBlock("Standing or Seated Calf Raise", "12-15", 3, 25.0, 2.5, 45, "Full stretch at bottom, strong pause at top extension."),
				doubleProgressionBlock("Dead Bug (Controlled Bracing)", "10-12 per side", 3, 0.0, 0.0, 45, "Glue lower back flat to the floor with zero arch. Slowly extend opposite arm and leg while breathing out."),
				cardioBlock("Stationary Bike or Incline Walk (Zone 2)", "10-15 min", "Gentle cooldown pace to finish the training session."),
			},
		},
		{
			Name:        "5/3/1 Boring But Big (BBB)",
			Description: "Jim Wendler's legendary strength and hypertrophy system. 4 days/week focusing on the 4 main compound lifts with multi-week percentage waves (3x5+ -> 3x3+ -> 5/3/1+ -> Deload), 5x10 supplemental volume (Boring But Big), and targeted upper back and core accessories.",
			Category:    "strength",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":          "4 weeks per cycle",
				"frequency":         "4 days/week",
				"level":             "intermediate",
				"training_max_rule": "Base all percentages on 85-90% of true 1RM (Training Max). Add +2.5kg to upper body TM and +5kg to lower body TM each 4-week cycle.",
			},
			Blocks: []templateBlockSeed{
				// DAY 1 - OVERHEAD PRESS & UPPER BACK
				sectionBlock("Day 1 - Overhead Press Focus", "5/3/1 OHP main wave, 5x10 OHP supplemental volume, lat pulldowns and hanging knee raises.", "day"),
				wendler531WaveBlock("Barbell Overhead Press", 180),
				restBlock(120),
				linearProgressionBlockWithNotes("Overhead Press (BBB 5x10)", "10", "kg", 5, 20.0, 1.25, 90, "BBB Supplemental: 5 sets of 10 @ 50-60% Training Max."),
				restBlock(90),
				linearProgressionBlockWithNotes("Lat Pulldown (or Chin-Up)", "10-12", "kg", 3, 40.0, 2.5, 60, "Accessory Lat Volume: 3-5 sets for upper back balance and shoulder health."),
				restBlock(60),
				exerciseBlockWithNotes("Hanging Knee / Leg Raise", "10-15", 3, "Abdominal compression and hip flexor control."),

				// DAY 2 - DEADLIFT & CORE
				sectionBlock("Day 2 - Deadlift Focus", "5/3/1 Deadlift main wave, 5x10 Deadlift supplemental volume, core anti-extension, and single-leg work.", "day"),
				wendler531WaveBlock("Barbell Deadlift", 180),
				restBlock(120),
				linearProgressionBlockWithNotes("Barbell Deadlift (BBB 5x10)", "10", "kg", 5, 50.0, 2.5, 90, "BBB Supplemental: 5 sets of 10 @ 50-60% Training Max."),
				restBlock(90),
				timedExerciseBlock("Plank Hold (Set 1: 45s)", 45),
				restBlock(45),
				timedExerciseBlock("Plank Hold (Set 2: 45s)", 45),
				restBlock(45),
				timedExerciseBlock("Plank Hold (Set 3: 45s)", 45),
				restBlock(60),
				exerciseBlockWithNotes("Dumbbell Single-Leg RDL", "10 per side", 3, "Unilateral stability and hamstring stretch."),

				// DAY 3 - BENCH PRESS & UPPER BACK
				sectionBlock("Day 3 - Bench Press Focus", "5/3/1 Bench Press main wave, 5x10 Bench supplemental volume, dumbbell rows and face pulls.", "day"),
				wendler531WaveBlock("Barbell Bench Press", 180),
				restBlock(120),
				linearProgressionBlockWithNotes("Barbell Bench Press (BBB 5x10)", "10", "kg", 5, 35.0, 2.5, 90, "BBB Supplemental: 5 sets of 10 @ 50-60% Training Max."),
				restBlock(90),
				linearProgressionBlockWithNotes("Dumbbell / Barbell Row", "10-12", "kg", 3, 30.0, 2.5, 60, "Accessory Horizontal Pull: 3-5 sets for back thickness."),
				restBlock(60),
				exerciseBlockWithNotes("Cable Face Pull", "15", 3, "Rotator cuff and rear delt reinforcement."),

				// DAY 4 - SQUAT & ABS
				sectionBlock("Day 4 - Squat Focus", "5/3/1 Squat main wave, 5x10 Squat supplemental volume, leg curls and machine crunches.", "day"),
				wendler531WaveBlock("Barbell Squat", 180),
				restBlock(120),
				linearProgressionBlockWithNotes("Barbell Squat (BBB 5x10)", "10", "kg", 5, 40.0, 2.5, 90, "BBB Supplemental: 5 sets of 10 @ 50-60% Training Max."),
				restBlock(90),
				exerciseBlockWithNotes("Lying or Seated Leg Curl", "12-15", 3, "Knee flexion balance for hamstrings."),
				restBlock(60),
				exerciseBlockWithNotes("Abdominal Machine Crunch", "15", 3, "Controlled abdominal flexion."),
			},
		},
		{
			Name:        "The Recommended Routine (r/bodyweightfitness)",
			Description: "The gold-standard full-body calisthenics routine from r/bodyweightfitness. 3 days/week full-body strength work organized into antagonistic pairs (3x5-8) with double progression and a functional core triplet.",
			Category:    "calisthenics",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "12 weeks",
				"frequency": "3 days/week",
				"level":     "all_levels",
			},
			Blocks: append(
				append(recommendedRoutineDayBlocks(1), recommendedRoutineDayBlocks(2)...),
				recommendedRoutineDayBlocks(3)...,
			),
		},
		{
			Name:        "GZCLP Hypertrophy (4-Day + 2 Active Rest)",
			Description: "Customized GZCLP modified for maximum hypertrophy: 5x3+ T1 and 3x10 T2 schemes with bounce-to-base on success, T3 progression requiring AMRAP >= 20 and total > 50 reps, plus 2 dedicated active recovery conditioning days.",
			Category:    "strength",
			IsOfficial:  true,
			Metadata: map[string]any{
				"duration":  "12 weeks",
				"frequency": "4-6 days/week",
				"level":     "intermediate",
				"warmup":    "1x10 bar only, 1x5 at 50% target, 1x3 at 70%",
				"deload":    "Every 4-6 weeks: reduce load by 20% and volume by 50% for 1 week.",
			},
			Blocks: []templateBlockSeed{
				// DAY A - Overhead Press & Deadlift
				sectionBlock("Day A - Overhead Press & Deadlift", "T1 Overhead Press (5x3+), T2 Deadlift (3x10), T3 Rows, and Lateral Raises.", "day"),
				gzclpHypertrophyT1Block("Barbell Overhead Press", 35.0, "kg", 2.0, 180, "T1 Main Compound. 5x3+ -> 6x2+ (bounce-to-base on pass). Rest 3-5 min."),
				restBlock(180),
				gzclpHypertrophyT2Block("Barbell Deadlift", 70.0, "kg", 5.0, 120, "T2 Volume Hinge. 3x10 -> 3x8 -> 3x6 (bounce-to-base on pass). Rest 2-3 min."),
				restBlock(120),
				gzclpHypertrophyT3Block("Barbell Bent-Over Row", "15+", 3, 35.0, "kg", 2.5, 60, "T3 Horizontal Pull. AMRAP >= 20 and sum > 50 to advance. Rest 1-2 min."),
				restBlock(60),
				gzclpHypertrophyT3Block("Dumbbell Lateral Raise", "15+", 3, 6.0, "kg", 1.0, 60, "T3 Lateral Delt Isolation. AMRAP >= 20 and sum > 50 to advance. Rest 1-2 min."),

				// DAY B - Squat & Bench
				sectionBlock("Day B - Squat & Bench", "T1 Squat (5x3+), T2 Bench Press (3x10), T3 Lat Pulldown, and Leg Curl.", "day"),
				gzclpHypertrophyT1Block("Barbell Squat", 60.0, "kg", 2.5, 180, "T1 Main Compound. 5x3+ -> 6x2+ (bounce-to-base on pass). Rest 3-5 min."),
				restBlock(180),
				gzclpHypertrophyT2Block("Barbell Bench Press", 45.0, "kg", 2.5, 120, "T2 Volume Press. 3x10 -> 3x8 -> 3x6 (bounce-to-base on pass). Rest 2-3 min."),
				restBlock(120),
				gzclpHypertrophyT3Block("Lat Pulldown", "15+", 3, 40.0, "kg", 2.5, 60, "T3 Vertical Pull. AMRAP >= 20 and sum > 50 to advance. Rest 1-2 min."),
				restBlock(60),
				gzclpHypertrophyT3Block("Leg Curl", "15+", 3, 35.0, "kg", 2.5, 60, "T3 Knee Flexion (Hamstrings). AMRAP >= 20 and sum > 50 to advance. Rest 1-2 min."),

				// DAY C - Deadlift & Overhead Press
				sectionBlock("Day C - Deadlift & Overhead Press", "T1 Deadlift (5x3+), T2 Overhead Press (3x10), T3 Rows, and Face Pulls.", "day"),
				gzclpHypertrophyT1Block("Barbell Deadlift", 85.0, "kg", 5.0, 180, "T1 Main Compound. 5x3+ -> 6x2+ (bounce-to-base on pass). Rest 3-5 min."),
				restBlock(180),
				gzclpHypertrophyT2Block("Barbell Overhead Press", 25.0, "kg", 2.0, 120, "T2 Volume Press. 3x10 -> 3x8 -> 3x6 (bounce-to-base on pass). Rest 2-3 min."),
				restBlock(120),
				gzclpHypertrophyT3Block("Barbell Bent-Over Row", "15+", 3, 35.0, "kg", 2.5, 60, "T3 Horizontal Pull. AMRAP >= 20 and sum > 50 to advance. Rest 1-2 min."),
				restBlock(60),
				gzclpHypertrophyT3Block("Cable Face Pull", "15+", 3, 15.0, "kg", 1.0, 60, "T3 Rear Delts & Rotator Cuff. AMRAP >= 20 and sum > 50 to advance. Rest 1-2 min."),

				// DAY D - Bench Press & Squat
				sectionBlock("Day D - Bench Press & Squat", "T1 Bench Press (5x3+), T2 Squat (3x10), T3 Lat Pulldown, and Leg Press.", "day"),
				gzclpHypertrophyT1Block("Barbell Bench Press", 55.0, "kg", 2.5, 180, "T1 Main Compound. 5x3+ -> 6x2+ (bounce-to-base on pass). Rest 3-5 min."),
				restBlock(180),
				gzclpHypertrophyT2Block("Barbell Squat", 50.0, "kg", 2.5, 120, "T2 Volume Squat. 3x10 -> 3x8 -> 3x6 (bounce-to-base on pass). Rest 2-3 min."),
				restBlock(120),
				gzclpHypertrophyT3Block("Lat Pulldown", "15+", 3, 40.0, "kg", 2.5, 60, "T3 Vertical Pull. AMRAP >= 20 and sum > 50 to advance. Rest 1-2 min."),
				restBlock(60),
				gzclpHypertrophyT3Block("Leg Press", "15+", 3, 90.0, "kg", 5.0, 60, "T3 Quad Hypertrophy. AMRAP >= 20 and sum > 50 to advance. Rest 1-2 min."),

				// REST DAY 1
				sectionBlock("Rest Day 1 - Cardio, Core & Calves", "15 min steady-state cardio, plank and russian twists, standing calf raises.", "cardio"),
				timedExerciseBlock("Cardio: Steady-State Brisk Walking / Cycling (15 min)", 900),
				restBlock(60),
				timedExerciseBlock("Plank Hold (Set 1: 45s)", 45),
				restBlock(45),
				timedExerciseBlock("Plank Hold (Set 2: 45s)", 45),
				restBlock(45),
				timedExerciseBlock("Plank Hold (Set 3: 45s)", 45),
				restBlock(60),
				exerciseBlockWithNotes("Russian Twists", "15 per side", 3, "Rotational abdominal stability. 3 sets of 15 each side."),
				restBlock(60),
				exerciseBlockWithNotes("Standing Calf Raise", "15", 3, "Calves isolation. 2s pause at top contraction."),

				// REST DAY 2
				sectionBlock("Rest Day 2 - Cardio, Core & Calves", "20 min light jogging or elliptical, machine crunch, hollow body holds, seated calf raises.", "cardio"),
				timedExerciseBlock("Cardio: Light Jogging / Elliptical (20 min)", 1200),
				restBlock(60),
				exerciseBlockWithNotes("Machine Crunch", "15", 3, "Controlled abdominal flexion. 3 sets of 15."),
				restBlock(60),
				timedExerciseBlock("Isometric Hold: Hollow Body (Set 1: 20s)", 20),
				restBlock(30),
				timedExerciseBlock("Isometric Hold: Hollow Body (Set 2: 20s)", 20),
				restBlock(30),
				timedExerciseBlock("Isometric Hold: Hollow Body (Set 3: 20s)", 20),
				restBlock(60),
				exerciseBlockWithNotes("Seated Calf Raise", "20", 3, "Soleus isolation. 3 sets of 20 with full stretch."),
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
