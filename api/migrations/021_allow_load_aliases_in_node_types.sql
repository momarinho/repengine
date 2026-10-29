-- Migration 021: Allow load aliases in node_types schema for exercise, linear_progression, and superset
UPDATE node_types
SET schema = schema || '{"load": null, "target_load": null}'::jsonb
WHERE slug = 'exercise';

UPDATE node_types
SET schema = schema || '{"load": null, "load_value": null, "target_load": null}'::jsonb
WHERE slug = 'linear_progression';

UPDATE node_types
SET schema = schema || '{"load_value_a": null, "load_value_b": null, "load_a": null, "load_b": null, "target_load_a": null, "target_load_b": null}'::jsonb
WHERE slug = 'superset';

-- Down
UPDATE node_types
SET schema = schema - 'load' - 'target_load'
WHERE slug = 'exercise';

UPDATE node_types
SET schema = schema - 'load' - 'load_value' - 'target_load'
WHERE slug = 'linear_progression';

UPDATE node_types
SET schema = schema - 'load_value_a' - 'load_value_b' - 'load_a' - 'load_b' - 'target_load_a' - 'target_load_b'
WHERE slug = 'superset';
