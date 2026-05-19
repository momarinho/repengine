ALTER TABLE users
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

UPDATE users
SET updated_at = created_at
WHERE updated_at IS NULL;

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(128) NOT NULL UNIQUE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  used_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id
  ON password_reset_tokens(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expires_at
  ON password_reset_tokens(expires_at)
  WHERE used_at IS NULL;

UPDATE workout_sessions
SET completed_at = NOW()
WHERE status = 'abandoned'
  AND completed_at IS NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_workout_sessions_status'
  ) THEN
    ALTER TABLE workout_sessions
      DROP CONSTRAINT chk_workout_sessions_status;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_workout_sessions_status'
  ) THEN
    ALTER TABLE workout_sessions
      ADD CONSTRAINT chk_workout_sessions_status
      CHECK (status IN ('active', 'completed', 'abandoned'));
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_workout_sessions_completed_at'
  ) THEN
    ALTER TABLE workout_sessions
      DROP CONSTRAINT chk_workout_sessions_completed_at;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_workout_sessions_completed_at'
  ) THEN
    ALTER TABLE workout_sessions
      ADD CONSTRAINT chk_workout_sessions_completed_at
      CHECK (
        (status = 'active' AND completed_at IS NULL)
        OR (status IN ('completed', 'abandoned') AND completed_at IS NOT NULL)
      );
  END IF;
END $$;
