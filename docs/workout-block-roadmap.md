# Workout Block Roadmap

## Current Decision

The workout editor should keep distinct block types for distinct programming models:

- `exercise`: simple fixed prescription.
- `wave`: set-by-set wave loading with week presets.
- `linear_progression`: session-to-session load progression.
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
