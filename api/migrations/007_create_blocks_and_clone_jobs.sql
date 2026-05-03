CREATE TABLE IF NOT EXISTS template_blocks (
    id SERIAL PRIMARY KEY,
    template_id INTEGER NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
    node_type_slug VARCHAR(50) NOT NULL REFERENCES node_types(slug),
    position INTEGER NOT NULL,
    data JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS clone_jobs (
    id SERIAL PRIMARY KEY,
    template_id INTEGER NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    workflow_id INTEGER REFERENCES workflows(id) ON DELETE SET NULL,
    idempotency_key VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(template_id, user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_template_blocks_template_id ON template_blocks(template_id);
CREATE INDEX IF NOT EXISTS idx_clone_jobs_user_id ON clone_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_clone_jobs_template_user_key ON clone_jobs(template_id, user_id, idempotency_key);

-- DROP TABLE IF EXISTS clone_jobs;
-- DROP TABLE IF EXISTS template_blocks;
