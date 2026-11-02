# TASK-020 — крафт каменного топора (разработка, НЕ релиз)

**Дата:** 2 ноября 2026. **Ветка:** `feature/TASK-020-stone-axe-crafting`. **Production:** v0.5.2, без новой миграции и без крафта.

## Цель

Добавить первый полезный инструмент и связать крафт с существующим костром, сбором ресурсов, приватным инвентарём и сохранением PostgreSQL. Топор должен давать понятное игровое преимущество без возможности подделать действие клиентом.

## Уже реализовано в рабочем дереве

| Функция | Состояние |
| --- | --- |
| Рецепт: 2 wood + 2 stone | Код готов; проверка на сервере |
| Для крафта требуется костёр в радиусе 4 м | Код готов; негативный тест без костра PASS |
| Запрет второго каменного топора | Код готов; тест повторного крафта PASS |
| Приватный инвентарь `axe: 0/1` | Godot/JSON/.NET schema code обновлены |
| Отмена расходов при ошибке сохранения | В коде; отдельный fault-injection тест ещё требуется |
| Добыча древесины топором | 2 wood за удар, не больше остатка ресурса; локальный тест PASS |
| Кнопки | Windows C и Craft button; Android CRAFT AXE в панели Build mode |
| Сохранение после перезапуска Godot | **JSON E2E PASS** (два отдельных запуска) |
| SQL-миграция `003_stone_axe.sql` | Подготовлена, **не выполнена в production** |
| Полный PostgreSQL E2E | Сценарий добавлен в тестовый скрипт, полный PASS ещё не подтверждён |
| APK/ZIP и публичный сервер | **Не обновлялись** |

## Какие файлы менялись

- `client/main.gd` — команда `request_craft_axe`, серверная стоимость/радиус/откат, 2 wood за удар, кнопки.
- `client/world_save.gd` — `axe` в тестовом JSON-снимке.
- `client/postgres_world_store.gd` — поддержка `axe` в профиле и проверка диапазона 0..1.
- `server/Eldoria.Persistence/Program.cs` — чтение/проверка/запись нового поля.
- `server/Eldoria.Persistence/sql/003_stone_axe.sql` — новый столбец `eldoria_players.axe integer DEFAULT 0 CHECK (axe BETWEEN 0 AND 1)`.
- `client/tests/craft_axe_e2e.gd` — тест реального крафта и восстановления после отдельного рестарта.
- `tests/run_dev_gameplay_e2e.sh`, `tests/run_postgres_e2e.sh` — расширение регрессии (в процессе).

## Проверка фактического состояния

На 2 ноября непосредственно выполнены:

```bash
GODOT_BIN="$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64"
tmp=$(mktemp -d)
ELDORIA_SAVE_PATH="$tmp/world.json" "$GODOT_BIN" --headless --path client \
  --script res://tests/craft_axe_e2e.gd -- --initial
ELDORIA_SAVE_PATH="$tmp/world.json" "$GODOT_BIN" --headless --path client \
  --script res://tests/craft_axe_e2e.gd -- --restored
rm -rf "$tmp"
```

Результат: `CRAFT AXE INITIAL PASS`, `CRAFT AXE RESTORED PASS`; Godot headless import PASS. Это **не** подтверждение миграции PostgreSQL, физического Android и общего сетевого крафта.

## Перед будущим релизом

1. Применить `003_stone_axe.sql` к **изолированной тестовой БД**, проверить совместимость профилей без `axe`, пробежать `tests/run_postgres_e2e.sh` с новым и существующим профилем.
2. Проверить два клиента и антиэксплойт: удалённый крафт, недостаток материалов, повторный крафт, неправильный/чужой ID, ошибку БД, double-submit; убедиться, что rollback реально восстанавливает инвентарь и состояние.
3. Проверить Android UI в OpenGL и на устройстве, затем выполнить полный `tests/run_dev_gameplay_e2e.sh`. **Только по отдельной команде пользователя** обновлять production API/таблицы/сервер/сборки.

Не выдавать текущий незакоммиченный код TASK-020 за завершённый релиз.
