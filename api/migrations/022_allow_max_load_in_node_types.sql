-- Migration 022: Allow max_load and on_max_load in node_types schema for linear_progression and exercise
UPDATE node_types
SET schema = schema || '{"max_load": null, "on_max_load": null}'::jsonb
WHERE slug IN ('linear_progression', 'exercise');

-- Down
UPDATE node_types
SET schema = schema - 'max_load' - 'on_max_load'
WHERE slug IN ('linear_progression', 'exercise');
