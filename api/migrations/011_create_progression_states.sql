CREATE TABLE IF NOT EXISTS progression_states (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    workflow_id INTEGER NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    workflow_block_id INTEGER,
    block_key VARCHAR(255) NOT NULL,
    node_type_slug VARCHAR(50) NOT NULL,
    state_type VARCHAR(30) NOT NULL,
    exercise_name VARCHAR(255),
    outcome VARCHAR(30) NOT NULL,
    current_load VARCHAR(50),
    suggested_load VARCHAR(50),
    current_week INTEGER,
    suggested_week INTEGER,
    suggested_intensity_offset VARCHAR(50),
    avg_actual_rpe VARCHAR(50),
    avg_actual_rir VARCHAR(50),
    last_session_id INTEGER REFERENCES workout_sessions(id) ON DELETE SET NULL,
    last_log_count INTEGER NOT NULL DEFAULT 0,
    summary TEXT,
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE workout_set_logs
    ADD COLUMN IF NOT EXISTS actual_rir VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_progression_states_workflow_id
    ON progression_states(workflow_id);

CREATE INDEX IF NOT EXISTS idx_progression_states_user_id
    ON progression_states(user_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_progression_states_user_workflow_block_key
    ON progression_states(user_id, workflow_id, block_key);
