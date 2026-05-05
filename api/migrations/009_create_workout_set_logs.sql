 CREATE TABLE IF NOT EXISTS workout_set_logs (
      id SERIAL PRIMARY KEY,
      session_id INTEGER NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
      workflow_block_id INTEGER,
      block_client_id VARCHAR(100),
      node_type_slug VARCHAR(50) NOT NULL,
      set_index INTEGER NOT NULL,
      prescribed_reps VARCHAR(50),
      prescribed_load VARCHAR(50),
      prescribed_intensity VARCHAR(50),
      prescribed_rpe VARCHAR(50),
      actual_reps VARCHAR(50),
      actual_load VARCHAR(50),
      actual_rpe VARCHAR(50),
      completed BOOLEAN NOT NULL DEFAULT TRUE,
      notes TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_workout_set_logs_session_id ON workout_set_logs(session_id);
  CREATE INDEX IF NOT EXISTS idx_workout_set_logs_workflow_block_id ON workout_set_logs(workflow_block_id);
