-- TASK-087.06: additive schema-1 extension. Apply to a backed-up database
-- before deploying the matching persistence API. Existing depleted trees get
-- 0 (no auto-regrowth), not an artificial 5-minute deadline.
ALTER TABLE eldoria_resources
    ADD COLUMN IF NOT EXISTS regrow_at_unix bigint NOT NULL DEFAULT 0
    CHECK (regrow_at_unix BETWEEN 0 AND 4102444800);