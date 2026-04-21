CREATE TABLE IF NOT EXISTS users
(
    id
    SERIAL
    PRIMARY
    KEY,
    email
    VARCHAR
(
    255
) NOT NULL UNIQUE,
    password_hash VARCHAR
(
    255
) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

-- Down
DROP TABLE IF EXISTS users;

Then add a function in api/db/db.go to run migrations:

  func RunMigrations(ctx context.Context) error {
      query := `
          CREATE TABLE IF NOT EXISTS users (
              id          SERIAL PRIMARY KEY,
              email       VARCHAR(255) NOT NULL UNIQUE,
              password_hash VARCHAR(255) NOT NULL,
              created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );
      `
      _, err := Pool.Exec(ctx, query)
      return err
  }