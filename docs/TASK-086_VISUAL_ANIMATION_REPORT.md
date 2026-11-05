# TASK-086 — Visual & Animation Sprint

Дата проверки: 2026-11-05. Issue: https://github.com/niko009/eldoria-game/issues/17.
Ветка: `feature/TASK-086-visual-animation-sprint`, база — актуальная
`feature/TASK-064-wildlife-hud`, `a16a036dba381b56b967cd981ab81f3ed962ba65`.
Перед созданием ветки рабочее дерево было чистым; remote SHA повторно проверен перед PR.
Разработка и QA выполнены без merge, экспорта APK/ZIP, публикации или production-деплоя.

## Компоненты и границы

Вся новая логика представления находится в `client/visual_fx/`:

| Файл | Ответственность |
|---|---|
| `actor_events.gd` | `play_visual_event(event, data)` для idle/walk/run/sprint/attack/melee/hit/death/cast/bow_draw/bow_release/equip/harvest; использует реальные KayKit-клипы. Read-only адаптер читает существующий `player_health` родительского мира для смерти/возрождения. |
| `bow_motion.gd` | Две части тетивы, плавное натяжение/сброс, вертикальная ориентация лука в левой руке. KayKit ranged-клип исходно рассчитан на арбалет; ориентация рекурсивного лука исправлена независимо от положения кости. |
| `effect_pool.gd` | Общий для сцены MultiMesh: попадание, добыча, пыль/короткие следы, магический импульс, лечение, след рывка и защитное кольцо. Один материал, одна геометрия, один draw call без теней. |
| `creature_motion.gd` | Плавные процедурные hit/death-реакции травоядных без изменения их корневой позиции. Короткий косметический труп не имеет коллизии, AI, идентификатора цели или полосы здоровья. |
| `Preview.tscn`, `preview.gd` | Автономная воспроизводимая демонстрация, PNG и измерение кадров. Не загружает Main, сеть или сохранения. |

Узкие адаптеры: `animated_actor.gd`, `wolf_actor.gd`, `passive_actor.gd`,
`graphics_profile.gd`. `client/main.gd`, сетевой протокол, серверные правила,
инвентарь, крафт, UI, выбор целей, лес, SQL/API и сохранения **не изменены**.
Ассеты KayKit/Quaternius и их лицензии переиспользованы; новых внешних ассетов нет.

Действия возвращаются к недавнему walk/run, а не всегда в Idle. Смерть удерживает
позу и блокирует перебивающие действия; существующий положительный HP-снимок
восстанавливает Idle. Анимации не перемещают корневой узел игрока или его hitbox.
Dedicated-ветка героя не создаёт модель; пул не создаёт геометрию на dedicated-сервере.

Посох, копьё, топор и щит сохраняют существующие модели. Лук использует левый
socket; посох + щит используют разные руки. Переключение оружия проигрывает Interact.
При экипированном топоре убран накладывавшийся на него fallback-посох мага.
В живой игре траекторию стрелы по-прежнему показывает существующий серверный
`ArrowTracer`: новая тетива не рисует вторую стрелу по локальному направлению.
Флаг `preview_projectiles` разрешён только в автономном демо/тесте, по умолчанию false.
Три существующих типа магических снарядов (огонь/лёд/аркан) сохранены;
новые эффекты кастования, лечения и рывка дополняют существующие события.
Кольцо taunt также доступно через общий API; существующий игровой taunt и его звук сохранены.
Звуки TASK-062, их cooldown и лимит каналов не дублируются.

Волк сохраняет настоящие Idle/Walk/Gallop/Attack/HitReact/Death, но поворачивается
плавно с учётом delta. У травоядных повторный HP/смертельный снимок не повторяет
реакцию; respawn удаляет старый косметический труп. Авторитетная видимость
мёртвого животного по-прежнему выключается сразу.

## Бюджеты

| Параметр | High | Low |
|---|---:|---:|
| Активные частицы/следы, суммарно для всех актёров | 96 | 24 |
| Короткие косметические трупы | 4 | 2 |
| Число новых материалов для частиц во всём мире | 1 | 1 |
| Draw calls самого пула | 1 | 1 |
| Частицы обычного магического burst | 12 | 4 |
| Частицы шага, интервал не менее 0,3 с на актёра | 3 | 1 |

Переключение High → Low обрезает уже активный пул на следующем кадре. Тетива —
две низкополигональные линии с переиспользованным материалом старой тетивы.
Пул использует непрозрачный StandardMaterial3D с instance colors: без новых
шейдеров, текстур, освещения или per-particle Node/Tween/Material. Краткий труп
переиспользует ресурсы модели и удаляется через 1,15 с. Low по умолчанию на Android.
Это бюджеты нового модуля, а не ограничение всех существующих эффектов Main.

## Воспроизведение

Godot: **4.5.2.stable.official.6ce3de25a**.

```powershell
./tests/run_task086_visual_qa.ps1 -GodotBin <Godot_v4.5.2-stable_win64_console.exe> -Render
```

Runner останавливается при ненулевом exit code или ERROR/FAIL в логе. Логи находятся
в игнорируемом `tests/logs/`; артефакты — `tests/artifacts/task086/{high,low}`.
Без `-Render` выполняются import и headless-проверки, но это не визуальная приёмка.

```bash
GODOT_BIN=/path/to/godot bash tests/run_websocket_e2e.sh
GODOT_BIN=/path/to/godot bash tests/run_task086_visual_network_e2e.sh
godot --path client --rendering-method gl_compatibility res://visual_fx/Preview.tscn -- --capture-dir=/absolute/output
godot --path client --rendering-method gl_compatibility res://visual_fx/Preview.tscn -- --low --capture-dir=/absolute/output-low
```

Для before/after использован отдельный detached worktree на `a16a036`. В него
скопированы только preview-файлы и скрипт пула для загрузки demo; `--baseline`
не создаёт пул и не вызывает новый API. Игровые исходники baseline не изменялись.

## Выполненные проверки

| Команда / сценарий | Exit | Результат |
|---|---:|---|
| Godot `--headless --path client --editor --quit` | 0 | Финальный import/parser, без ошибок |
| `run_task086_visual_qa.ps1 ... -Render` | 0 | 11 headless-тестов, 3 реальных OpenGL-теста, 2 demo-прогона |
| `task086_events_e2e.gd` | 0 | Все события, 3 скелета, death hold, возврат к движению, dedicated |
| `task086_effects_e2e.gd` | 0 | Посох+щит, тетива, preview-стрела, смена оружия, классовые эффекты, лимиты и удаление частиц |
| `task086_creatures_e2e.gd` | 0 | Hit/death/respawn, дубликаты снимков, поворот волка и пыль |
| `animated_actor`, `camera_profile`, `task057_animation_action` | 0 каждый | Анимации, существующая камера/прыжок, подтверждённые действия |
| `task076_wolf_windup`, `task061_rigged_wolf`, `task048_passive` | 0 каждый | Windup, скелетный волк, пассивные животные |
| `task072_equipment_validation`, `task073_staff_ui` | 0 каждый | Существующая матрица экипировки и посох |
| `task035_interaction`, `task056_combat_vfx`, `task062_game_audio` | 0 каждый | Реальный Windows OpenGL: добыча, боевые эффекты, звук |
| `bash tests/run_task086_visual_network_e2e.sh` (Windows/Git Bash и Linux) | 0 | Dedicated host + 2 процесса-клиента, одинаковые анимации/тетива/волк/смерть и respawn игрока |
| `bash tests/run_websocket_e2e.sh` (Linux) | 0 | Два клиента: движение, Wave, disconnect/reconnect |
| High/Low baseline и TASK-086 preview | 0 каждый | Настоящий Windows OpenGL, PNG + metrics.json |
| `git diff --check` | 0 | Нет whitespace-ошибок |

Оба клиента нового сетевого теста получили одинаковую последовательность:
`2H_Ranged_Shoot, Spellcast_Shoot, Dodge_Forward, Hit_A, Death_A`;
оба увидели натяжение лука, попадание/смерть волка и сброс death-позы после HP=100.
Тест использует существующие authority RPC, не добавляя игровой протокол.
Linux-проверки выполнялись в отдельной копии `/home/coder/eldoria-task086`;
из-за занятого другим процессом 7788 **только в этой копии** listener и адреса
тестов заменены на 17788. Это не вошло в ветку; посторонние процессы не останавливались.

## Настоящий рендер и измерения

Windows, **Intel UHD Graphics 730**, OpenGL Compatibility, 1280×720, VSync off,
лимит 120 FPS. После прогрева и восьми демонстрационных фаз — 30 burst-циклов
через 0,2 с, примерно 6,25 с измерений; интервалы кадров получены через
`Time.get_ticks_usec()`, сохранение PNG исключено из измеряемого участка.

| Сценарий | Средний FPS | p95 кадра, мс | Peak draw calls | Peak частиц нового пула | Static memory, байт |
|---|---:|---:|---:|---:|---:|
| baseline High | 120,00 | 8,355 | 113 | 0 | 49 123 201 |
| TASK-086 High | 120,00 | 8,355 | 110 | 96 | 49 473 550 |
| baseline Low | 120,00 | 8,354 | 57 | 0 | 49 060 689 |
| TASK-086 Low | 120,00 | 8,356 | 56 | 24 | 49 367 310 |

Все прогоны достигли FPS cap: это **не измерение максимального FPS**, не доказательство
ускорения и не оценка полной игровой сцены. Static memory — счётчик Godot, не RSS/VRAM.
Снижение draw calls относительно baseline связано в том числе с удалением
перекрывающего топор fallback-посоха в демонстрации; это не чистый GPU-бенчмарк пула.
Фактические значения и число кадров: [High](../tests/artifacts/task086/high/metrics.json),
[Low](../tests/artifacts/task086/low/metrics.json),
[baseline High](../tests/artifacts/task086/baseline-high/metrics.json),
[baseline Low](../tests/artifacts/task086/baseline-low/metrics.json).

PNG сняты из настоящего viewport; проверены позы, крепление лука и посоха+щита,
эффекты классов, падение героев/животных и различие High/Low. Ниже before/after:

| Фаза | Baseline High | TASK-086 High | TASK-086 Low |
|---|---|---|---|
| Idle | [PNG](../tests/artifacts/task086/baseline-high/idle.png) | [PNG](../tests/artifacts/task086/high/idle.png) | [PNG](../tests/artifacts/task086/low/idle.png) |
| Run | [PNG](../tests/artifacts/task086/baseline-high/run.png) | [PNG](../tests/artifacts/task086/high/run.png) | [PNG](../tests/artifacts/task086/low/run.png) |
| Attack | [PNG](../tests/artifacts/task086/baseline-high/attack.png) | [PNG](../tests/artifacts/task086/high/attack.png) | [PNG](../tests/artifacts/task086/low/attack.png) |
| Cast | [PNG](../tests/artifacts/task086/baseline-high/cast.png) | [PNG](../tests/artifacts/task086/high/cast.png) | [PNG](../tests/artifacts/task086/low/cast.png) |
| Equipment | [PNG](../tests/artifacts/task086/baseline-high/equipment.png) | [PNG](../tests/artifacts/task086/high/equipment.png) | [PNG](../tests/artifacts/task086/low/equipment.png) |
| Death | [PNG](../tests/artifacts/task086/baseline-high/death.png) | [PNG](../tests/artifacts/task086/high/death.png) | [PNG](../tests/artifacts/task086/low/death.png) |

Также сохранены harvest/hit и baseline Low. Это демонстрационная сцена,
а не кадры production или тест Android. Death baseline снят на 0,3 с,
финальный death — на 0,65 с, чтобы видеть законченное падение; остальные фазы
используют одинаковое окно захвата.

## Ограничения и диагностированные исходные сбои

- Физические Android ARM64, touch, нагрев, длительный игровой сеанс, FPS и память
  Android **не проверены**. Windows-проверка использует Godot, а не экспортированный ZIP.
- Камера/коллизии проверены существующим тестом; отдельная визуальная приёмка
  first-person на устройстве не выполнялась. Камеры и контроллер не изменены.
- Godot MCP: health check вернул `bridge_connected=true`, однако инспекция проекта
  завершилась `TIMEOUT`. Старую MCP-копию не считали доказательством текущей ветки.
  Для визуальной приёмки использован локальный Windows viewport текущих исходников.
- `task033_equipment_e2e.gd` падает на remote Mage axe: на исходной базе уже
  автоматически экипируется посох. Exit 1 одинаков на базе и этой ветке.
- `task058_wolf_reaction_e2e.gd` ожидает мгновенный укус, несовместимый с TASK-076
  windup. Exit 1 одинаков на базе и этой ветке. Актуальные TASK-061/076 проходят.
- Windows запуск старого `run_websocket_e2e.sh`: все клиентские PASS-маркеры есть,
  но принудительная остановка dedicated-процесса из Git Bash вызывает Godot
  `Unreferenced static string` и runner exit 1. Полный Linux-прогон той же проверки — 0.
- Первый импорт после смены старой ветки дал `get_multiple_md5: f.is_null()` при
  обновлении кэша. Последующие и финальный import — exit 0 без ошибок. Кэши и
  переимпортированные чужие `.import`/`.uid` файлы не включены в PR.

## Список изменений

- Новые модули `client/visual_fx/{actor_events,bow_motion,creature_motion,effect_pool,preview}.gd`, `Preview.tscn` и их `.uid`.
- Адаптеры `client/{animated_actor,wolf_actor,passive_actor,graphics_profile}.gd`.
- Новые тесты `client/tests/task086_{events,effects,creatures,network}_e2e.gd` и `.uid`.
- Runner `tests/run_task086_visual_qa.ps1`, `tests/run_task086_visual_network_e2e.sh`.
- Реальные PNG/JSON в `tests/artifacts/task086/`.
- Этот отчёт и ссылка в `docs/HANDOFF_NEXT_CHAT.md`.

Четыре содержательных коммита: API/переходы; оружие/эффекты;
существа/окружение; QA/preview/проверенные корректировки и отчёт.
