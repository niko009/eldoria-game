-- Additive migration: preserve existing player rows and inventories.
-- Legacy profiles receive an empty equipment state, interpreted as unequipped.
ALTER TABLE eldoria_players
    ADD COLUMN IF NOT EXISTS equipment jsonb NOT NULL DEFAULT '{}'::jsonb;