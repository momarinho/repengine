UPDATE node_types
SET schema = '{
    "times": 3,
    "rounds": 3,
    "title": "",
    "reps": "",
    "interval_phases": []
}'::jsonb
WHERE slug = 'repeat';

UPDATE node_types
SET schema = '{
    "exercise_name": "",
    "sets": 3,
    "reps": "",
    "rest_seconds": 90,
    "notes": "",
    "load_value": null,
    "load_unit": "kg"
}'::jsonb
WHERE slug = 'exercise';

UPDATE node_types
SET schema = '{
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
    "notes": "",
    "deload_weeks": null,
    "deload_percent": null
}'::jsonb
WHERE slug = 'linear_progression';

UPDATE node_types
SET schema = '{
    "title": "Day 1",
    "subtitle": "",
    "kind": "day",
    "collapsed": false,
    "label": ""
}'::jsonb
WHERE slug = 'section';

UPDATE node_types
SET schema = '{
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
}'::jsonb
WHERE slug = 'wave';

-- Down
UPDATE node_types SET schema = '{"times": 3}'::jsonb WHERE slug = 'repeat';
UPDATE node_types SET schema = '{"exercise_name": "", "sets": 3, "reps": "", "rest_seconds": 90, "notes": ""}'::jsonb WHERE slug = 'exercise';
