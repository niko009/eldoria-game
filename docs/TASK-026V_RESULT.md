# TASK-026V — результат

## Реализация

- `client/forest_world.gd`: более спокойные дневное освещение и воздух, палитра земли и гор, неровная непрозрачная водная поверхность с цветом по вершинам и береговые акценты. Декоративный проход выполняется **после** завершения генерации ресурсов и MultiMesh. Новых коллизий, loot и RNG-вызовов нет. GL Compatibility и прежние Low/High сохранены.
- `client/building_object.gd`: тёплый emissive материал двух элементов существующего костра без нового динамического света.
- `client/performance_overlay.gd`, `client/main.gd`, `client/ui/live_ui.gd`: локальная диагностика F9 или из настроек. По умолчанию выключена. Окно 300 кадров показывает avg FPS, 5%-low FPS, p95, process/physics time и render objects/draw calls при доступном monitor, качество, видимые центры деревьев/деталей в камере, размер viewport и зону camp/forest/lake. Память обозначена «нет данных»: старое поле удалённой телеметрии не является достоверным RSS в release. Ни один показатель debug overlay не отправляется в сеть и не записывается на диск.
- `client/tests/task026v_capture.gd`: воспроизводимый захват трёх фиксированных камер для Low/High; проверка подписи ресурсов. `client/tests/task026v_diagnostics_e2e.gd`: проверка включения, выключения и содержимого overlay. [План физических замеров](TASK-026V_DEVICE_TEST_PLAN.md).

## Скриншоты

Настоящий Godot 4.5.2, Intel UHD Graphics 730, OpenGL 3.3 Compatibility. Для каждой пары камера, освещение и размер 1280×720 одинаковы; кадры до изменений сняты до правки сцены. Все PNG находятся в [`docs/screenshots/task026v`](screenshots/task026v/).

| Сцена | Low до → после | High до → после |
|---|---|---|
| Лагерь | [до](screenshots/task026v/before_camp_low.png) → [после](screenshots/task026v/after_camp_low.png) | [до](screenshots/task026v/before_camp_high.png) → [после](screenshots/task026v/after_camp_high.png) |
| Лес | [до](screenshots/task026v/before_forest_low.png) → [после](screenshots/task026v/after_forest_low.png) | [до](screenshots/task026v/before_forest_high.png) → [после](screenshots/task026v/after_forest_high.png) |
| Озеро | [до](screenshots/task026v/before_lake_low.png) → [после](screenshots/task026v/after_lake_low.png) | [до](screenshots/task026v/before_lake_high.png) → [после](screenshots/task026v/after_lake_high.png) |

HUD поверх реальной сцены: [camp Low](screenshots/task026v/after_camp_low_hud.png), [forest High](screenshots/task026v/after_forest_high_hud.png), [lake Low](screenshots/task026v/after_lake_low_hud.png). Снято в landscape 640×360: запрошенное окно 800×360 ограничено рендерером/окружением до 640×360. Нижняя панель остаётся векторной без счётчиков; числа ресурсов видны сверху.

Дополнительно: [лагерь с поставленным костром](screenshots/task026v/after_camp_high_fire.png) — локальный world preview с обычным `building_object.gd`, без сетевого сервера.

Воспроизведение: `Godot 4.5.2 --path client --resolution 1280x720 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/task026v_capture.gd -- --after`. Для HUD добавить `--hud --test-live-ui --test-mobile-ui` и запустить с `--resolution 800x360`; для кадра с костром добавить `--campfire`. Скрипт сохраняет файлы в `docs/screenshots/task026v`.

## Проверки

| Проверка | Результат |
|---|---|
| `--headless --editor --quit` (Godot 4.5.2) | PASS |
| `client/tests/live_ui_smoke.gd`, `client/ui_preview/preview_smoke.gd` | PASS |
| `client/tests/task026v_diagnostics_e2e.gd` headless и OpenGL | PASS |
| `tests/run_dev_gameplay_e2e.sh` в WSL с Godot 4.5.2 | PASS: ENet, two-client WebSocket, сбор, строительство, крафт, бой, сохранение, joystick, коллизии, OpenGL MultiMesh resource visibility |
| Подпись resource ID/позиции до и после | PASS: 347 записей, hash `1181774555` в обоих захватах |
| Low/High PNG и HUD | PASS: 12 сценовых PNG 1280×720 + 6 HUD PNG 640×360 + 1 кадр костра |

## Ограничения

- На двух физических Android замеров и проверки сенсорных целей пока нет. Локальные FPS Windows не сравнивались с Android; таблица до/после FPS не составлена без повторяемых измерений на одинаковом железе и рендерере.
- Вода остаётся статическим stylized слоем и местами может визуально не совпадать с рельефом: игровую `height_at` и коллизии намеренно не меняли ради совместимости существующего мира. Отражений и дорогого mobile shader нет.
- Исходный утверждённый художественный PNG недоступен; композиция следует текстовому стилю D и существующему HUD. Соответствие исходному концепт-арту не заявляется.
- `Performance.get_monitor()` даёт метрики процесса Godot, не аппаратный GPU/RSS. В release достоверный RSS не выводится. Формат production telemetry/API/SQL не менялся.
