# TASK-087.07 / TASK-087.08 — World atmosphere

Work branch: `feature/TASK-087-world-atmosphere`. Base: `a16a036`,
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
worktree at `a16a036`, with only the survey harness copied into it.

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

`docs/TASK-087_GAMEPLAY_WORLD_UI_POLISH.md` is absent from the requested base.
The attached TASK-087.07/.08 specification is the scope authority.

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
- High: **10 438** новых пакетных деталей, 12 MultiMesh-групп, дистанции
  58/75 м, 24 светлячка в одной группе только ночью. Low: **2 264** детали,
  6 видимых групп, дистанция 40 м, без светлячков и дополнительных огней костра.
  Геометрия ориентиров одинакова в обоих профилях. Материалы Low — стандартные,
  без дорогих экранных эффектов, прозрачности или новых текстурных загрузок.
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
| `task087_world_contract` | PASS: все 355 ресурсов и 164 старые коллизии побитно совпали по хешу; 3 ориентира; новые опоры не перекрывают сбор; плотность Low ниже High |
| `forest_resource_visual_e2e`, Windows OpenGL | PASS: видимость/истощение/возврат дерева и травы, коллизия срубленного дерева |
| `task063_atmosphere_e2e`, Windows OpenGL | PASS: переходы день/ночь, ближайшие 2 костра, отсутствие теней огней, выключение эффектов Low, очистка |
| `forest_depletion_persistence_e2e`, два последовательных процесса | PASS: сохранение и восстановление истощённых ресурсов в отдельный временный JSON |
| Dedicated ENet + 2 процесса `resource_e2e` | PASS A/B: раздельный инвентарь, общий остаток ресурсов, late join |
| Dedicated WebSocket + 2 процесса `websocket_e2e` | PASS A/B: движение, взаимодействие, переподключение |

Полный общий `run_dev_gameplay_e2e.sh` не запускался: выполнен профильный набор,
указанный выше. Новая PostgreSQL БД не создавалась и production не использовался.
Ранние неудачные прогоны (ошибка вывода типа GDScript, сравнение JSON int/float,
подавление рендера перекрытого окна) исправлены; они не учитываются как PASS.

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

## Ограничения и выпуск

- Физический Android недоступен: `adb devices -l` не показывает устройств.
  FPS/p95 на телефоне, touch/safe area и длительный нагрев **не проверены**.
  Windows Low — проверка профиля, не замена Android-приёмки.
- Декоративные цветы/пни/руны не дают лут. Ориентиры пока без квестов.
- Добавленные твёрдые опоры требуют одинаковой ревизии мира на клиентах и
  dedicated server. Обновлять только клиента против старого сервера нельзя.
  Существующие сохранённые объекты не удаляются и не переносятся.
- Высотное поле намеренно сохранено: визуальное разнообразие рельефа усилено
  материалами, растительностью и каменистыми деталями без изменения физики земли.
- Во временном MCP-редакторе есть предупреждение о локальном Android build-tools;
  Android-экспорт не запускался. Runtime-проверки выше не выдали ошибок.
- **Merge, релизная ветка, APK/Windows release и production-деплой не выполнялись.**
