-- TASK-049. Additive, zero-default migration: preserves all existing player rows.
-- Run with a backup and in an isolated PostgreSQL first.
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS bandage integer NOT NULL DEFAULT 0 CHECK (bandage BETWEEN 0 AND 20);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS repair_kit integer NOT NULL DEFAULT 0 CHECK (repair_kit BETWEEN 0 AND 20);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS spear integer NOT NULL DEFAULT 0 CHECK (spear BETWEEN 0 AND 1);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS bow integer NOT NULL DEFAULT 0 CHECK (bow BETWEEN 0 AND 1);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS shield integer NOT NULL DEFAULT 0 CHECK (shield BETWEEN 0 AND 1);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS arrow integer NOT NULL DEFAULT 0 CHECK (arrow BETWEEN 0 AND 40);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS archery_xp integer NOT NULL DEFAULT 0 CHECK (archery_xp BETWEEN 0 AND 1000000);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS spear_xp integer NOT NULL DEFAULT 0 CHECK (spear_xp BETWEEN 0 AND 1000000);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS defense_xp integer NOT NULL DEFAULT 0 CHECK (defense_xp BETWEEN 0 AND 1000000);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS magic_xp integer NOT NULL DEFAULT 0 CHECK (magic_xp BETWEEN 0 AND 1000000);
