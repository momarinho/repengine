CREATE TABLE IF NOT EXISTS user_training_maxes (
    id            SERIAL PRIMARY KEY,
    user_id       INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exercise_name VARCHAR(100) NOT NULL,
    value         NUMERIC(10,2) NOT NULL,
    unit          VARCHAR(10) NOT NULL DEFAULT 'kg',
    updated_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_user_exercise_tm UNIQUE(user_id, exercise_name)
);

CREATE INDEX IF NOT EXISTS idx_user_training_maxes_user_exercise 
  ON user_training_maxes(user_id, exercise_name);

-- Down
DROP INDEX IF EXISTS idx_user_training_maxes_user_exercise;
DROP TABLE IF EXISTS user_training_maxes;
