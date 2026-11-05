-- Additive schema update for first craftable mage weapon.
ALTER TABLE eldoria_players
    ADD COLUMN IF NOT EXISTS wooden_staff integer NOT NULL DEFAULT 0
    CHECK (wooden_staff BETWEEN 0 AND 1);