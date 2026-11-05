# TASK-083 — Сквозная валидация, миграции и выпуск (P0, TODO)

**Риск:** TASK-072/074/075/078 добавляют серверное состояние: слоты экипировки, magic_xp/доступные заклинания, виды трав/манапоты, новые AI и добычу. Ранее в Eldoria новые предметы выпадали из персистентного DTO: повторения этой ошибки недопустимы.

**План:**
1. Каждое новое поле появляется одновременно в `main.gd`, Godot `postgres_world_store.gd`, `world_save.gd`, .NET `Program.cs`, аддитивном `sql/*.sql`, DTO/API валидациях и UI. Сохранить поддержку старых записей (zero/default + миграция).
2. Данные игрока: `equipment`, `magic_xp`, `mana_potion`, `mana_herb`, crafted staffs/gear + owned quantities. Старые `equipped_combat` конвертировать детерминированно. Не доверять клиенту slot values/XP.
3. Автотесты: server-authoritative RPC, cooldown, crafting race (двое игроков одновременно), damage/loot idempotency, reconnect, restart PostgreSQL, действительно проверенная физическая UI раскладка, health/mana potion.
4. Изолированная PostgreSQL 16 + .NET 10 E2E, проверка сохранения старых 5 профилей/XP/ресурсов; отрицательные тесты invalid slots/XP/стеков и stale revision 409.
5. До production: `git diff --check`, Godot editor import, full `tests/run_dev_gameplay_e2e.sh` exit 0, отдельный DB test, сборка Android/Windows + SHA/signing, backup `pg_dump -Fc`, миграция БД и API до смены Godot-сервера. Не восстанавливать БД автоматически при ошибке релиза.
6. После: `ELDORIA_RELEASE_SUCCESS`, публичный manifest/APK/ZIP 200, оба systemd active, `PERSISTENCE LOADED`, zero data-loss, no new critical errors, сеть Windows+Android.

**AC:** ни одно новое действие/рецепт не теряет предметы при рестарте; экипировка не активируется по факту владения; магический XP и мана доступны после reload; тесты новой версии запускаются только на выделенной dev базе, production мигрирует **строго аддитивно** с предварительной резервной копией.
