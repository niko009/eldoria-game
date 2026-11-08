-- TASK-088 / A-06: additive, manual pre-production migration.
-- Back up the production DB first. Do not apply unless the new API is deployed.
ALTER TABLE public.eldoria_players
    ADD COLUMN IF NOT EXISTS quests jsonb NOT NULL DEFAULT '{}'::jsonb;
-- Existing profiles remain {} (unstarted), no implicit payouts or retroactive credit.
