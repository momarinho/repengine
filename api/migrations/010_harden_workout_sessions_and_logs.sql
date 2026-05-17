ALTER TABLE workout_sessions
  ADD COLUMN IF NOT EXISTS section_id VARCHAR(100);

ALTER TABLE workout_sessions
  ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE workout_sessions
  ALTER COLUMN status SET DEFAULT 'active';

ALTER TABLE workout_set_logs
  ADD COLUMN IF NOT EXISTS block_client_id VARCHAR(100);

ALTER TABLE workout_set_logs
  ADD COLUMN IF NOT EXISTS set_index INTEGER DEFAULT 1;

ALTER TABLE workout_set_logs
  ADD COLUMN IF NOT EXISTS prescribed_reps VARCHAR(50);

ALTER TABLE workout_set_logs
  ADD COLUMN IF NOT EXISTS prescribed_load VARCHAR(50);

ALTER TABLE workout_set_logs
  ADD COLUMN IF NOT EXISTS prescribed_intensity VARCHAR(50);

ALTER TABLE workout_set_logs
  ADD COLUMN IF NOT EXISTS prescribed_rpe VARCHAR(50);

ALTER TABLE workout_set_logs
  ALTER COLUMN block_position SET DEFAULT 0;

ALTER TABLE workout_set_logs
  ALTER COLUMN set_number SET DEFAULT 1;

ALTER TABLE workout_set_logs
  ALTER COLUMN actual_reps TYPE VARCHAR(50) USING actual_reps::TEXT;

ALTER TABLE workout_set_logs
  ALTER COLUMN actual_load TYPE VARCHAR(50) USING actual_load::TEXT;

ALTER TABLE workout_set_logs
  ALTER COLUMN actual_rpe TYPE VARCHAR(50) USING actual_rpe::TEXT;

WITH ranked_sessions AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY user_id, workflow_id
           ORDER BY id DESC
         ) AS row_num
  FROM workout_sessions
  WHERE status = 'active'
)
UPDATE workout_sessions
SET
  status = 'completed',
  completed_at = COALESCE(completed_at, NOW())
WHERE id IN (
  SELECT id FROM ranked_sessions WHERE row_num > 1
);

WITH ranked_logs AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY session_id, block_client_id, set_index
           ORDER BY id DESC
         ) AS row_num
  FROM workout_set_logs
  WHERE block_client_id IS NOT NULL
    AND block_client_id <> ''
)
DELETE FROM workout_set_logs
WHERE id IN (
  SELECT id FROM ranked_logs WHERE row_num > 1
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_sessions_active_workflow
  ON workout_sessions(user_id, workflow_id)
  WHERE status = 'active';

CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_set_logs_session_block_set
  ON workout_set_logs(session_id, block_client_id, set_index)
  WHERE block_client_id IS NOT NULL AND block_client_id <> '';
