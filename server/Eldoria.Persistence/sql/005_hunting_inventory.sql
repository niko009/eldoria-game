-- TASK-069. Additive, zero-default migration preserving existing players.
-- Back up production before applying. Does not reset worlds, XP or inventory.
BEGIN;
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS meat integer NOT NULL DEFAULT 0 CHECK (meat BETWEEN 0 AND 1000000);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS hide integer NOT NULL DEFAULT 0 CHECK (hide BETWEEN 0 AND 1000000);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS bone integer NOT NULL DEFAULT 0 CHECK (bone BETWEEN 0 AND 1000000);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS leather_armor integer NOT NULL DEFAULT 0 CHECK (leather_armor BETWEEN 0 AND 1);
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS grilled_meat integer NOT NULL DEFAULT 0 CHECK (grilled_meat BETWEEN 0 AND 20);
COMMIT;