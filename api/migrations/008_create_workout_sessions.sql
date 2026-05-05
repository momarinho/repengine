CREATE TABLE IF NOT EXISTS workout_sessions (
    id SERIAL PRIMARY KEY,
    workflow_id INTEGER NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    section_id VARCHAR(100),
    section_title VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_workout_sessions_user_id ON workout_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_workout_sessions_workflow_id ON workout_sessions(workflow_id);
CREATE INDEX IF NOT EXISTS idx_workout_sessions_status_id ON workout_sessions(status);
