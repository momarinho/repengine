# Workout Block Roadmap

## Current Decision

The workout editor should keep distinct block types for distinct programming models:

- `exercise`: simple fixed prescription.
- `wave`: set-by-set wave loading with week presets.
- `linear_progression`: session-to-session load progression.
- `deload`: active recovery protocol, scheduled frequency, and baseline-preserving progression guard.
- `section`: visual and logical divider for days, phases, or groups.

Avoid turning `wave` into a generic progression block. It should stay focused on programs like 5/3/1 where one block contains multiple set prescriptions and week-specific variations.

## Section V1

`section` remains a flat block in persistence. It works as a delimiter:

- a `section` starts a group;
- following blocks belong to that group until the next `section`;
- the frontend can collapse/expand groups;
- the player can start from a selected section/day.

No `parent_block_id` or tree structure is required for V1.

Future V2 can add structural nesting if moving a whole section with children becomes necessary.

## Wave Block

`wave` should be an executable block, similar to an exercise block, but with set prescriptions generated from the active week.

Core fields:

```json
{
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
  "week_4_rpe": ""
}
```

New `wave` blocks should be mostly empty. Prescriptive values like `5/5/5+` and `65/75/85` belong in official templates, not in the default node type schema.

The regular properties panel should expose:

- exercise name;
- active week;
- suggested rest;
- reps, intensity, and RPE for each week.

Advanced settings can later hold calculation behavior such as rounding, training max, load units, deload rules, or auto-calculated loads.

## Linear Progression Block

Many programs use linear progression rather than wave loading. This should be represented as a separate node type:

```text
linear_progression
```

Suggested initial schema:

```json
{
  "exercise_name": "",
  "sets": 3,
  "reps": "5",
  "start_load": null,
  "load_unit": "kg",
  "increment": 2.5,
  "progression_rule": "add_each_session",
  "rest_seconds": 120
}
```

Likely future fields:

- `reset_rule`;
- `failure_rule`;
- `deload_percent`;
- `target_rpe`;
- `sessions_per_week`;
- `microload_allowed`.

Player behavior:

- execute set by set like `exercise`;
- show current load target;
- show planned increment and rule;
- complete only after all sets are logged.

## Deload Block (Active Recovery Protocol)

In strength programming and calisthenics, systematic fatigue accumulation requires scheduled deload periods (typically every 4 to 6 weeks) to dissipate systemic CNS fatigue, reduce connective tissue strain, and resensitize muscle fibers to hypertrophy/strength stimuli.

The `deload` block defines routine-level recovery parameters and directly integrates with both the Routine Architect and the Workout Player.

### Node Type Slug
```text
deload
```

### Canonical Data Schema
```json
{
  "title": "Scheduled Deload Protocol",
  "frequency_weeks": 4,
  "strategy": "volume_intensity",
  "volume_reduction_pct": 50,
  "intensity_reduction_pct": 10,
  "target_rir": 3,
  "is_active": false,
  "notes": "Reduce total working sets by half. Keep weights light, crisp, and focus on movement quality."
}
```

### Core Configuration Fields
- `frequency_weeks` (int): Number of training weeks before activating a deload block (e.g., 4 to 8 weeks).
- `strategy` (enum: `volume`, `intensity`, `volume_intensity`):
  - `volume`: Cut working sets by 40-50%, maintaining working load to preserve neuromuscular intensity.
  - `intensity`: Drop working weight by 10-20% while performing normal set/rep volume.
  - `volume_intensity`: Hybrid reduction (standard for heavy compound and calisthenics routines).
- `volume_reduction_pct` (int): Target volume reduction (typically 40-50%).
- `intensity_reduction_pct` (int): Target intensity or load reduction (typically 10-20%).
- `target_rir` (int): Target Reps In Reserve during deload sets (3-4 RIR recommended).
- `is_active` (bool): Manual activation toggle for the current training cycle.
- `notes` (string): Coach cues, mobility instructions, or custom notes.

### Baseline-Preserving Progression Mechanics
A critical flaw in naive training apps is treating a deload session (where logged sets and loads are intentionally reduced) as a stall, plateau, or failure—improperly decreasing working weights upon resuming normal training.

RepEngine solves this with **Baseline-Preserving Progression Protection**:
1. When a routine with an active `deload` block is completed (or `is_deload: true` is passed), the Go Core progression engine (`api/internal/progression_states/service.go`) intercepts the evaluation.
2. The engine computes `OutcomeMaintain`, tags metadata with `is_deload: true`, and **preserves the athlete's pre-deload `SuggestedLoad` intact**.
3. Upon completing the deload week and deactivating the block, the subsequent normal workout session immediately resumes from the true baseline weight without any penalty or regression.

### Player Behavior
- Displays a dedicated active recovery status banner in the top app bar (`Deload` badge).
- Injects an **Active Recovery Protocol** milestone card showing configured volume cuts, target RIR, and coach cues.
- Provides a one-tap acknowledgment action (`Acknowledge Protocol`) without obstructing set logging.

## Template Mapping

Use block types according to the program:

- `5/3/1`: use `wave`.
- `GZCLP`: use `linear_progression` for T1/T2 style progression.
- accessory work: use `exercise`.
- day/group boundaries: use `section`.

## Implementation Order

1. Make the default `wave` schema empty.
2. Confirm the `wave` properties panel exposes all core fields.
3. Add `linear_progression` to node type seeds.
4. Add `BlockLinearProgression.svelte`.
5. Add editor properties for `linear_progression`.
6. Add player normalization and execution for `linear_progression`.
7. Update GZCLP template blocks to use `linear_progression`.
8. Validate clone, editor, and player flows.
