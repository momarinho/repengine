-- Migration 019: Add deload node type
INSERT INTO node_types (slug, name, description, icon, schema)
VALUES (
    'deload',
    'Deload & Recovery',
    'Configures scheduled active recovery or deload parameters for routine blocks',
    'battery_charging_full',
    '{
        "title": "Deload & Recovery Protocol",
        "frequency_weeks": 4,
        "strategy": "volume",
        "volume_reduction_percent": 40,
        "intensity_reduction_percent": 15,
        "target_rir": 3,
        "notes": "Reduce fatigue and promote joint recovery. Cap sets and stop well before failure.",
        "is_active": false
    }'
)
ON CONFLICT (slug) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    schema = EXCLUDED.schema;

-- Down
DELETE FROM node_types WHERE slug = 'deload';
