-- TASK-020 developer-only migration. Never execute against production until next authorized release.
ALTER TABLE eldoria_players
    ADD COLUMN IF NOT EXISTS axe integer NOT NULL DEFAULT 0 CHECK (axe BETWEEN 0 AND 1);
