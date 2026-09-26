-- Migration 017: Offline sync support, idempotency, and soft delete

-- 1. Idempotency for workout sessions created offline on mobile
ALTER TABLE workout_sessions
  ADD COLUMN IF NOT EXISTS client_id VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_sessions_client_id
  ON workout_sessions(client_id)
  WHERE client_id IS NOT NULL AND client_id <> '';

-- 2. Idempotency for individual set logs created offline
ALTER TABLE workout_set_logs
  ADD COLUMN IF NOT EXISTS client_id VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_set_logs_client_id
  ON workout_set_logs(client_id)
  WHERE client_id IS NOT NULL AND client_id <> '';

-- 3. Soft delete for workflows (routines) to propagate deletions via delta sync
ALTER TABLE workflows
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_workflows_deleted_at
  ON workflows(deleted_at)
  WHERE deleted_at IS NOT NULL;
