-- Migration 018: Allow progression in node_types schema for exercise, exercise_timed, and linear_progression
UPDATE node_types
SET schema = jsonb_set(schema, '{progression}', 'null')
WHERE slug IN ('exercise', 'exercise_timed', 'linear_progression');

-- Down
UPDATE node_types
SET schema = schema - 'progression'
WHERE slug IN ('exercise', 'exercise_timed', 'linear_progression');
