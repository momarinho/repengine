CREATE TABLE IF NOT EXISTS workflow_blocks (
    id SERIAL PRIMARY KEY,
    workflow_id INTEGER NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    node_type_slug VARCHAR(50) NOT NULL REFERENCES node_types(slug),
    position INTEGER NOT NULL,
    data JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workflow_blocks_workflow_id
    ON workflow_blocks(workflow_id);

-- Down
DROP TABLE IF EXISTS workflow_blocks;
