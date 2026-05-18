ALTER TABLE workout_set_logs
  ADD COLUMN IF NOT EXISTS actual_load_value NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS actual_rpe_value NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS actual_rir_value NUMERIC(4,2);

ALTER TABLE progression_states
  ADD COLUMN IF NOT EXISTS current_load_value NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS suggested_load_value NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS suggested_intensity_offset_value NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS avg_actual_rpe_value NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS avg_actual_rir_value NUMERIC(4,2);

UPDATE workout_sessions
SET completed_at = NOW()
WHERE status = 'completed'
  AND completed_at IS NULL;

UPDATE workout_sessions
SET completed_at = NULL
WHERE status = 'active'
  AND completed_at IS NOT NULL;

UPDATE workout_set_logs AS logs
SET workflow_block_id = NULL
WHERE workflow_block_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM workflow_blocks
    WHERE workflow_blocks.id = logs.workflow_block_id
  );

UPDATE progression_states AS states
SET workflow_block_id = NULL
WHERE workflow_block_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM workflow_blocks
    WHERE workflow_blocks.id = states.workflow_block_id
  );

UPDATE workout_set_logs
SET
  actual_load_value = CASE
    WHEN actual_load ~ '-?[0-9]+(\.[0-9]+)?'
      THEN substring(actual_load FROM '-?[0-9]+(\.[0-9]+)?')::NUMERIC(10,2)
    ELSE NULL
  END,
  actual_rpe_value = CASE
    WHEN actual_rpe ~ '-?[0-9]+(\.[0-9]+)?'
      THEN substring(actual_rpe FROM '-?[0-9]+(\.[0-9]+)?')::NUMERIC(4,2)
    ELSE NULL
  END,
  actual_rir_value = CASE
    WHEN actual_rir ~ '-?[0-9]+(\.[0-9]+)?'
      THEN substring(actual_rir FROM '-?[0-9]+(\.[0-9]+)?')::NUMERIC(4,2)
    ELSE NULL
  END
WHERE
  actual_load_value IS NULL
  OR actual_rpe_value IS NULL
  OR actual_rir_value IS NULL;

UPDATE progression_states
SET
  current_load_value = CASE
    WHEN current_load ~ '-?[0-9]+(\.[0-9]+)?'
      THEN substring(current_load FROM '-?[0-9]+(\.[0-9]+)?')::NUMERIC(10,2)
    ELSE NULL
  END,
  suggested_load_value = CASE
    WHEN suggested_load ~ '-?[0-9]+(\.[0-9]+)?'
      THEN substring(suggested_load FROM '-?[0-9]+(\.[0-9]+)?')::NUMERIC(10,2)
    ELSE NULL
  END,
  suggested_intensity_offset_value = CASE
    WHEN suggested_intensity_offset ~ '-?[0-9]+(\.[0-9]+)?'
      THEN substring(suggested_intensity_offset FROM '-?[0-9]+(\.[0-9]+)?')::NUMERIC(5,2)
    ELSE NULL
  END,
  avg_actual_rpe_value = CASE
    WHEN avg_actual_rpe ~ '-?[0-9]+(\.[0-9]+)?'
      THEN substring(avg_actual_rpe FROM '-?[0-9]+(\.[0-9]+)?')::NUMERIC(4,2)
    ELSE NULL
  END,
  avg_actual_rir_value = CASE
    WHEN avg_actual_rir ~ '-?[0-9]+(\.[0-9]+)?'
      THEN substring(avg_actual_rir FROM '-?[0-9]+(\.[0-9]+)?')::NUMERIC(4,2)
    ELSE NULL
  END
WHERE
  current_load_value IS NULL
  OR suggested_load_value IS NULL
  OR suggested_intensity_offset_value IS NULL
  OR avg_actual_rpe_value IS NULL
  OR avg_actual_rir_value IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_workout_sessions_status'
  ) THEN
    ALTER TABLE workout_sessions
      ADD CONSTRAINT chk_workout_sessions_status
      CHECK (status IN ('active', 'completed'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_workout_sessions_completed_at'
  ) THEN
    ALTER TABLE workout_sessions
      ADD CONSTRAINT chk_workout_sessions_completed_at
      CHECK (
        (status = 'active' AND completed_at IS NULL)
        OR (status = 'completed' AND completed_at IS NOT NULL)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_workout_set_logs_set_index_positive'
  ) THEN
    ALTER TABLE workout_set_logs
      ADD CONSTRAINT chk_workout_set_logs_set_index_positive
      CHECK (set_index > 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_workout_set_logs_workflow_block'
  ) THEN
    ALTER TABLE workout_set_logs
      ADD CONSTRAINT fk_workout_set_logs_workflow_block
      FOREIGN KEY (workflow_block_id) REFERENCES workflow_blocks(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_clone_jobs_status'
  ) THEN
    ALTER TABLE clone_jobs
      ADD CONSTRAINT chk_clone_jobs_status
      CHECK (status IN ('pending', 'running', 'completed', 'failed'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_clone_jobs_attempts_non_negative'
  ) THEN
    ALTER TABLE clone_jobs
      ADD CONSTRAINT chk_clone_jobs_attempts_non_negative
      CHECK (attempts >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_progression_states_workflow_block'
  ) THEN
    ALTER TABLE progression_states
      ADD CONSTRAINT fk_progression_states_workflow_block
      FOREIGN KEY (workflow_block_id) REFERENCES workflow_blocks(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_progression_states_state_type'
  ) THEN
    ALTER TABLE progression_states
      ADD CONSTRAINT chk_progression_states_state_type
      CHECK (state_type IN ('linear', 'wave', 'skill'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_progression_states_outcome'
  ) THEN
    ALTER TABLE progression_states
      ADD CONSTRAINT chk_progression_states_outcome
      CHECK (outcome IN ('increase', 'maintain', 'reduce', 'advance', 'regress'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_progression_states_weeks_positive'
  ) THEN
    ALTER TABLE progression_states
      ADD CONSTRAINT chk_progression_states_weeks_positive
      CHECK (
        (current_week IS NULL OR current_week > 0)
        AND (suggested_week IS NULL OR suggested_week > 0)
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_progression_states_last_log_count_non_negative'
  ) THEN
    ALTER TABLE progression_states
      ADD CONSTRAINT chk_progression_states_last_log_count_non_negative
      CHECK (last_log_count >= 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_workout_sessions_user_workflow_id_desc
  ON workout_sessions(user_id, workflow_id, id DESC);

CREATE INDEX IF NOT EXISTS idx_workout_set_logs_session_id_id
  ON workout_set_logs(session_id, id ASC);

CREATE INDEX IF NOT EXISTS idx_progression_states_user_workflow_updated
  ON progression_states(user_id, workflow_id, updated_at DESC, id DESC);
