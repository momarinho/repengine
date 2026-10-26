-- Migration 020: Allow double and superset state_type in progression_states
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_progression_states_state_type'
  ) THEN
    ALTER TABLE progression_states
      DROP CONSTRAINT chk_progression_states_state_type;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_progression_states_state_type'
  ) THEN
    ALTER TABLE progression_states
      ADD CONSTRAINT chk_progression_states_state_type
      CHECK (state_type IN ('linear', 'wave', 'skill', 'double', 'superset'));
  END IF;
END $$;
