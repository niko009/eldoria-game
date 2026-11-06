# TASK-087.07 / TASK-087.08 — World atmosphere

Work branch: `feature/TASK-087-world-atmosphere`. Base: `f32598e`,
`origin/feature/TASK-064-wildlife-hud`. No merge or release authorized.

## A. Baseline audit

The current base already has eight Quaternius tree meshes, a rolling heightfield,
a path, pond, alpine backdrop, gatherable vegetation and a day/night transition.
It is not an empty scene. The remaining visual weaknesses are long empty gaps
between trees, disconnected plants without an understory, uniform trail edges,
little environmental storytelling, and an unshaded mountain backdrop that stays
bright while the ground and actors become difficult to read at night.

Baseline images are actual Godot 4.5.2 Windows OpenGL frames at 1024×576 on
Intel UHD Graphics 730. `client/atmosphere/Survey.tscn` instantiates the real
`Main.tscn` offline with two actors, a wolf, a tent and a campfire. It does not
host, connect to production, or save a world. Cameras, actors, resolution and
sampling are identical in Before/After. The baseline is a fresh detached
worktree at `f32598e`, with only the survey harness copied into it.

- [High baseline and measurements](../tests/artifacts/task087/before-high/metrics.json)
- [Low baseline and measurements](../tests/artifacts/task087/before-low/metrics.json)
- [Day clearing](../tests/artifacts/task087/before-high/clearing_day.png)
- [Night forest](../tests/artifacts/task087/before-high/forest_night.png)
- [Night encounter](../tests/artifacts/task087/before-high/encounter.png)

The baseline contract records 355 resources and 164 obstacle footprints in
`client/tests/task087_world_baseline.json`. The hashes cover ordered IDs, types,
positions, amounts, batch/index links, obstacle links and obstacle positions/radii.

MCP server/addon 2026.10.20.1 was verified against this task's actual worktree.
The built-in session had a stale port-bind error. A fresh local FastMCP STDIO
session restored the localhost bridge without publishing a port. Project
inspection, editor play, real runtime screenshot and stop succeeded. Addon and
probe are temporary local tools; they are not part of the shipped project.

The repository originally had a stale local TASK-064 reference at `a16a036`:
its fetch refspec tracks only TASK-021. This was detected before PR publication.
The reference was explicitly fetched, the task rebased onto `f32598e`, and
baseline/render/tests repeated. The now-present
`docs/TASK-087_GAMEPLAY_WORLD_UI_POLISH.md` was read; WORLD-01/02/03 match this
scope. Gameplay and UI backlog remain with the parallel agent. The preliminary
MCP baseline screenshot is from `a16a036`; the paired final comparisons use
`f32598e` on both sides (before/after this task).

## B–D. Реализовано

- Добавлен `client/atmosphere/world_dressing.gd`: собственный seed 870708,
  150 нерегулярных колоний растительности. Восточный подлесок с папоротниками,
  западные луговые группы с мелкими светлыми цветами, кусты, травяные пучки,
  россыпи камней, береговые заросли и неровные края дороги. Между группами
  остаются открытые поляны; стартовая зона, дорога и подходы к ресурсам свободны.
- Восемь существующих моделей деревьев получили вариации высоты крон; восточные
  сосны выше. Горизонтальные размеры, координаты стволов и ID не изменены.
  Восстановление срубленного дерева использует обновлённую исходную трансформацию.
- Добавлены низкие поваленные стволы, торцы древесины, пни, корни и ветви.
  Это декоративные детали ниже высоты шага, не новые источники ресурсов.
- Три постоянных ориентира: разрушенные ворота **(-24.80, -23.26)**,
  рунический каменный круг **(32.78, 12.69)** и заброшенная стоянка над берегом
  **(-36.00, 39.00)** (координаты X/Z). Положение ищется детерминированно вдали
  от ресурсов; восемь твёрдых опор добавлены в общую серверную сетку коллизий.
- Материалы: матовый серо-зелёный камень, мох, тёмная кора, светлые торцы,
  умеренно светящиеся бирюзовые руны, вершины/основания травы разных оттенков.
  Ground shader сохраняет существующую текстуру, но лучше показывает землю
  в тени. Высотная функция, берега/вода и игровые координаты не переписаны.
- Ночь: направленный свет 0.29 → 0.42, ambient 0.21 → 0.34, туман
  0.0036 → 0.0025. Добавлены луна, мягкий ореол и тонкие облака. Дальний
  unshaded backdrop теперь темнеет вместе с ночью. Персонажи и волк читаются
  на холодной земле; два ближайших костра в High дают более широкий тёплый свет
  (радиус 7 → 9 м, ночная энергия 1.05 → 1.65), без дополнительных теней.
- High: **9 581** новых пакетных деталей, 9 MultiMesh-групп, дистанции
  58/75 м, 24 светлячка в одной группе только ночью. Low: **3 001** деталь,
  3 видимые группы, дистанция 40 м, без светлячков и дополнительных огней костра.
  Геометрия ориентиров одинакова в обоих профилях. Материалы Low — стандартные,
  без дорогих экранных эффектов, прозрачности или новых текстурных загрузок.
  Для Low увеличена плотность дешёвых травяных треугольников; дополнительные
  импортированные кусты/папоротники остаются только в High. Так заполнение
  среднего плана не требует дорогих моделей на каждом пучке травы.
- Меши ориентиров объединены по пяти материалам. Новые мелкие детали не
  отбрасывают тени. Сбор, инвентарь, бой, XP, RPC, PostgreSQL и восстановление
  ресурсов не изменены. Новый декор не расходует RNG генерации ресурсов.

### Источники ассетов

Папоротник, кусты, высокая трава и деревья повторно используют уже включённый
Quaternius Stylized Nature MegaKit Standard, CC0; источник и лицензия указаны
в [TASK-007](TASK-007_IMPORT_FOREST.md). Новые трава, цветы, мелкие камни,
пни, ветви, руины, руны и кристалл построены процедурным кодом этой задачи.
Новых сторонних загрузок, заимствованных коммерческих моделей или текстур нет.

## E. Визуальная приёмка

[Открыть сравнение Before / After](../tests/artifacts/task087/compare.html)
— переключение 10 сцен и High/Low. Всего 40 оригинальных кадров.

| Проверка | Before High | After High |
|---|---|---|
| Стартовая поляна днём | [PNG](../tests/artifacts/task087/before-high/clearing_day.png) | [PNG](../tests/artifacts/task087/after-high/clearing_day.png) |
| Лес днём | [PNG](../tests/artifacts/task087/before-high/forest_day.png) | [PNG](../tests/artifacts/task087/after-high/forest_day.png) |
| Дорога | [PNG](../tests/artifacts/task087/before-high/road.png) | [PNG](../tests/artifacts/task087/after-high/road.png) |
| Лес ночью | [PNG](../tests/artifacts/task087/before-high/forest_night.png) | [PNG](../tests/artifacts/task087/after-high/forest_night.png) |
| Лагерь с костром ночью | [PNG](../tests/artifacts/task087/before-high/camp_night.png) | [PNG](../tests/artifacts/task087/after-high/camp_night.png) |
| Руины | [PNG](../tests/artifacts/task087/before-high/landmark.png) | [PNG](../tests/artifacts/task087/after-high/landmark.png) |
| Персонажи и волк | [PNG](../tests/artifacts/task087/before-high/encounter.png) | [PNG](../tests/artifacts/task087/after-high/encounter.png) |
| Каменный круг | [PNG](../tests/artifacts/task087/before-high/stone_circle.png) | [PNG](../tests/artifacts/task087/after-high/stone_circle.png) |
| Стоянка | [PNG](../tests/artifacts/task087/before-high/old_camp.png) | [PNG](../tests/artifacts/task087/after-high/old_camp.png) |
| Берег | [PNG](../tests/artifacts/task087/before-high/shore.png) | [PNG](../tests/artifacts/task087/after-high/shore.png) |

При просмотре выявлены и исправлены: закрытый кроной ракурс руин, слишком
гладкие колонны, невидимые боковые грани custom mesh при объединении с
индексированными примитивами и высота персонажей в тестовом стенде (протокол
хранит центр капсулы, а не подошвы). После исправлений сцены пересняты.

## Проверки

Команда: `./tests/run_task087_world_qa.ps1 -GodotBin <Godot-4.5.2-console.exe>`.
Каждый процесс завершён с exit **0**, проверены stdout/stderr на ошибки:

| Проверка | Результат |
|---|---|
| `--headless --editor --import`, загрузка Main (90 кадров) | PASS |
| `collision_perf_e2e` | PASS: движение/скольжение, коллизии, профили |
| `task037_collision_benchmark` | PASS: 2500 запросов, совпадение spatial grid и полного перебора |
| `task075_mana_herb_world_e2e` | PASS: существующие mana herbs |
| `task087_world_contract` | PASS: записи 355 ресурсов и 164 старых коллизий совпали по хешу; 3 ориентира; новые опоры не перекрывают сбор; плотность Low ниже High |
| `forest_resource_visual_e2e`, Windows OpenGL | PASS: видимость/истощение/возврат дерева и травы, коллизия срубленного дерева |
| `task063_atmosphere_e2e`, Windows OpenGL | PASS: переходы день/ночь, ближайшие 2 костра, отсутствие теней огней, выключение эффектов Low, очистка |
| `forest_depletion_persistence_e2e`, два последовательных процесса | PASS: сохранение и восстановление истощённых ресурсов в отдельный временный JSON |
| Dedicated ENet + 2 процесса `resource_e2e` | PASS A/B: раздельный инвентарь, общий остаток ресурсов, late join |
| Dedicated WebSocket + 2 процесса `websocket_e2e` | PASS A/B: движение, взаимодействие, переподключение |

Полный общий `run_dev_gameplay_e2e.sh` не запускался: выполнен профильный набор,
указанный выше. Новая PostgreSQL БД не создавалась и production не использовался.
Ранние неудачные прогоны (ошибка вывода типа GDScript, сравнение JSON int/float,
подавление рендера перекрытого окна) исправлены; они не учитываются как PASS.
После rebase первый import также выявил устаревшую запись MD5 в локальном
Godot-кэше; повторный полный import и весь профильный набор прошли без ошибок.
Сводка exit codes и фактические маркеры тестов сохранены в
[qa-results.json](../tests/artifacts/task087/qa-results.json) и
[qa-evidence.txt](../tests/artifacts/task087/qa-evidence.txt).

Финальный MCP-прогон: проверен путь task worktree и Godot 4.5.2; запущена
Survey через редактор, прочитано дерево работающей игры с WorldDressing,
получен [реальный кадр](../tests/artifacts/task087/mcp-after.png), затем
`godot_runtime_stop_scene` подтвердил `playing=false`. Отдельно проверен
[ночной небосвод с луной](../tests/artifacts/task087/night-sky/night_sky.png).

### Воспроизведение кадров

```powershell
& $GodotBin --path client --rendering-method gl_compatibility --disable-vsync `
  res://atmosphere/Survey.tscn -- --capture-dir=<absolute-output-directory>
# Добавить --low после разделителя -- для Low.
```

В стенде отключён автоматический render loop и выполняется ровно один
`RenderingServer.force_draw()` на каждый измеряемый кадр: иначе Windows может
продолжать `process_frame` без отрисовки перекрытого окна и выдавать ложные FPS.
После смены камеры/освещения — 1.5 с прогрева, затем 90 кадров. Это измеренная
пропускная способность рендерящегося стенда, не обещание FPS длительной игровой
сессии. Память — Godot `MEMORY_STATIC`, не полный RSS и не видеопамять.

## Производительность: финальный сравнительный прогон

Windows 11 / Intel UHD Graphics 730 / Godot 4.5.2 OpenGL / 1024×576 / VSync off. В ячейках — Before → After. Исходные JSON включены рядом с PNG. Это короткий render-throughput benchmark; значения Low около 145 FPS ограничены циклом стенда и не доказывают запас производительности телефона.

| Профиль / ракурс | FPS | p95, мс | Draw calls | Static memory, MiB |
|---|---:|---:|---:|---:|
| high / clearing_day | 38,5 → 34,3 | 83,2 → 92,1 | 479 → 493 | 56,7 → 66,5 |
| high / forest_day | 47,0 → 43,2 | 76,4 → 81,9 | 355 → 367 | 56,7 → 66,5 |
| high / road | 43,5 → 39,2 | 82,1 → 89,8 | 432 → 446 | 56,7 → 66,5 |
| high / forest_night | 47,2 → 43,7 | 76,1 → 81,4 | 355 → 368 | 56,7 → 66,5 |
| high / camp_night | 34,3 → 38,4 | 85,2 → 92,9 | 474 → 489 | 56,8 → 66,5 |
| high / landmark | 47,6 → 42,6 | 76,6 → 83,9 | 311 → 324 | 56,8 → 66,5 |
| high / encounter | 36,5 → 37,9 | 90,9 → 91,2 | 465 → 480 | 56,8 → 66,5 |
| high / stone_circle | 39,1 → 43,4 | 90,1 → 79,8 | 370 → 383 | 56,8 → 66,5 |
| high / old_camp | 43,8 → 46,0 | 69,5 → 75,1 | 202 → 215 | 57,6 → 66,5 |
| high / shore | 49,3 → 44,9 | 66,8 → 76,3 | 202 → 215 | 57,6 → 66,5 |
| low / clearing_day | 112,5 → 118,5 | 10,7 → 6,9 | 89 → 97 | 57,4 → 66,3 |
| low / forest_day | 145,1 → 145,0 | 6,9 → 6,9 | 34 → 41 | 57,4 → 66,3 |
| low / road | 145,1 → 145,0 | 6,9 → 6,9 | 94 → 101 | 57,5 → 66,3 |
| low / forest_night | 145,1 → 145,1 | 6,9 → 6,9 | 34 → 41 | 57,5 → 66,3 |
| low / camp_night | 145,0 → 145,1 | 6,9 → 6,9 | 89 → 97 | 57,5 → 66,3 |
| low / landmark | 145,1 → 145,1 | 6,9 → 7,0 | 29 → 37 | 57,5 → 66,3 |
| low / encounter | 145,1 → 145,1 | 6,9 → 6,9 | 92 → 99 | 57,5 → 66,3 |
| low / stone_circle | 145,1 → 145,1 | 6,9 → 6,9 | 94 → 99 | 57,5 → 66,3 |
| low / old_camp | 145,1 → 145,1 | 6,9 → 6,9 | 35 → 40 | 57,5 → 66,3 |
| low / shore | 145,1 → 145,1 | 6,9 → 6,9 | 35 → 43 | 57,5 → 66,3 |

## Ограничения и выпуск

- Физический Android недоступен: `adb devices -l` не показывает устройств.
  FPS/p95 на телефоне, touch/safe area и длительный нагрев **не проверены**.
  Windows Low — проверка профиля, не замена Android-приёмки.
- High имеет измеримую стоимость: например, стартовая поляна на UHD 730
  38.5 → 34.3 FPS. Профиль не объявляется бесплатным или оптимизированным
  для слабого телефона; для таких устройств предусмотрен Low. Долгая игровая
  сессия и GPU/RSS-профилирование не проводились.
- Декоративные цветы/пни/руны не дают лут. Ориентиры пока без квестов.
- Добавленные твёрдые опоры требуют одинаковой ревизии мира на клиентах и
  dedicated server. Обновлять только клиента против старого сервера нельзя.
  Существующие сохранённые объекты не удаляются и не переносятся.
- Высотное поле намеренно сохранено: визуальное разнообразие рельефа усилено
  материалами, растительностью и каменистыми деталями без изменения физики земли.
- Во временном MCP-редакторе есть предупреждение о локальном Android build-tools;
  Android-экспорт не запускался. Runtime-проверки выше не выдали ошибок.
- **Merge, релизная ветка, APK/Windows release и production-деплой не выполнялись.**
