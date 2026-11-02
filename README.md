# Eldoria Game

**Eldoria** — экспериментальная фэнтезийная 3D онлайн-игра с одним общим постоянным миром для **Windows и Android**. Долгосрочная идея: выживание, королевства, NPC, дипломатия, PvE/PvP и разрушаемый ландшафт. Большинство этих элементов пока **не реализовано**.

**Актуальный статус на 2 ноября 2026:**
- **Production v0.5.2** — опубликованы Windows x64 ZIP и Android ARM64 APK; публичный WSS-сервер, PostgreSQL и приватный .NET API работают.
- **TASK-020** — крафт каменного топора только в незавершённой рабочей ветке; **релиза нет**.
- **Важное:** перед оптимизацией нужны **реальные показания FPS** с Windows/Android, а не синтетическая тестовая запись.

**[Актуальное состояние и реализованные механики](docs/PROJECT_STATUS.md)** · **[Передача проекта/следующие действия](docs/HANDOFF_NEXT_CHAT.md)** · **[Первоначальная концепция](docs/ELDORIA_DESIGN_AND_ARCHITECTURE_v0.1.md)**

## Уже реализовано в v0.5.2

- Godot 4.5.2, 3D-лес, деревья/камни/трава, MultiMesh, High/Low, приблизительные коллизии и движение по рельефу.
- Три анимированных героя KayKit: рыцарь, разбойник, маг. Ходьба, бег, прыжки, эмоция Wave, рубка дерева.
- Публичный мультиплеер WSS: общий мир, взаимодействия, синхронизация и повторное подключение.
- Добыча древесины, камня, растений; личный инвентарь. Срубленные деревья и собранная трава исчезают; сохраняются изменения мира. Звуки, падение дерева, следы рубки.
- Строительство **костра (3 wood + 2 stone)** и **палатки (5 wood + 2 herb)** с серверными проверками и зелёным/красным 3D-предпросмотром.
- Android: аналоговый джойстик, действия Sprint/Jump/Gather, отдельный Build mode с PLACE/CANCEL. Windows: WASD, Shift, Space, F, B, V.
- Анонимная идентификация без логина и пароля; серверное сохранение инвентаря, персонажа, построек и ресурсов через .NET 10 + PostgreSQL 16.
- **Опциональная диагностика v0.5.2:** FPS/просадки кадров, p95 кадра, память, ping, Low/High; отправка примерно раз в минуту, настройка ON/OFF, хранение 14 дней.

Не реализованы: полноценные NPC, крафт в **опубликованной** сборке, бои, королевства, экономика, воксельные тоннели, разные биомы, масштабируемая MMO-инфраструктура. Подробные факты и ограничения — в [PROJECT_STATUS.md](docs/PROJECT_STATUS.md).

## Скачать

- **[Страница Eldoria (Windows/Android)](https://bacus.dev/projects/eldoria/)**
- [Манифест последнего релиза](https://bacus.dev/projects/eldoria/latest.json)
- [Конфигурация публичного сервера](https://bacus.dev/projects/eldoria/server.json)

Нынешний релиз — **v0.5.2**. Windows и Android должны использовать согласованную версию с сервером. Физические тесты предыдущих версий проводились пользователем; подтверждённые на реальных устройствах численные показатели FPS для v0.5.2 здесь ещё отсутствуют.

## Как устроено

```text
Windows / Android (Godot)
       | HTTPS manifest & server config
       | WSS: actions, movement, telemetry
       v
Cloudflare / Caddy
       |
       v
Dedicated Godot server (authoritative)
       | private HTTP, internal server key
       v
ASP.NET Core / .NET 10 persistence + telemetry API
       |
       v
PostgreSQL 16 (world / profiles / resources / buildings / telemetry)
```

**Godot — игровой сервер, .NET — API для хранения и анализа.** SQL не доступна напрямую игровым клиентам. Старые архитектурные документы, где .NET игровой сервер указан как ещё не реализованный план, — исторические и не отражают нынешнее состояние.

## Продолжающаяся разработка

[**TASK-020 — крафт каменного топора (DEV, не опубликован)**](docs/TASK-020_STONE_AXE_CRAFTING_DEV.md): у костра 2 дерева + 2 камня → топор; до 2 древесины за удар. Проверено изготовление и восстановление из **тестового JSON** после перезапуска Godot. Для публикации ещё нужны PostgreSQL-миграция и полная сетевая регрессия.

## Тесты и выпуск

Основные команды в репозитории (перед запуском настроить изолированную тестовую среду):

```bash
bash tests/run_dev_gameplay_e2e.sh     # Godot, ENet/WSS, графика, геймплей
bash tests/run_telemetry_e2e.sh       # клиент → выделенный сервер → приватный тестовый HTTP
bash tests/run_postgres_e2e.sh        # только изолированная PostgreSQL + .NET
dotnet build server/Eldoria.Persistence/Eldoria.Persistence.csproj -c Release
```

Для подготовки релиза: `tests/build_windows.sh`, `tests/build_android_debug.sh`, `tools/generate_manifest.js`. **Не выполнять деплой или production-миграцию без отдельного разрешения.**

## История задач

Архивные записи оставлены для аудита. Они отражают состояние **на дату выполнения**, поэтому старые утверждения «сервера нет» и «не опубликовано» более не относятся к текущей версии.

| Задачи | История реализации |
| --- | --- |
| TASK-001…005 | [Первые сетевые проверки](docs/TASK-001_VERIFICATION.md), [Android](docs/TASK-002_ANDROID_BUILD.md), [кроссплатформенность](docs/TASK-003_CROSS_PLATFORM.md), [автоподключение](docs/TASK-004_SERVER_DISCOVERY.md), [публичный WSS](docs/TASK-005_PUBLIC_MULTIPLAYER.md) |
| TASK-006…008 | [Лес и обновления](docs/TASK-006_FOREST_AND_UPDATES.md), [Quaternius](docs/TASK-007_IMPORT_FOREST.md), [коллизии и MultiMesh](docs/TASK-008_COLLISION_FPS.md) |
| TASK-009…010 | [Герои KayKit](docs/TASK-009_ANIMATED_CHARACTERS.md), [ориентация персонажа](docs/TASK-010_CHARACTER_ORIENTATION.md) |
| TASK-011…014 | [Геймплей](docs/TASK-011_GAMEPLAY_DEV.md), [джойстик/профиль](docs/TASK-012_JOYSTICK_PERSISTENCE.md), [PostgreSQL](docs/TASK-013_POSTGRESQL_PERSISTENCE.md), [строительство v0.5.0](docs/TASK-014_CAMP_BUILDING_RELEASE.md) |
| TASK-015…017 | [Исчезновение ресурсов](docs/TASK-015_BUILD_FIX_RESOURCE_DEPLETION.md), [визуальные эффекты](docs/TASK-016_HARVEST_VFX_BUILD_PREVIEW.md), [звуки и v0.5.1](docs/TASK-017_SFX_TREE_DAMAGE_MOBILE_RELEASE.md) |
| TASK-018…019 | [Телеметрия](docs/TASK-018_PERFORMANCE_TELEMETRY.md), [релиз v0.5.2](docs/TASK-019_TELEMETRY_RELEASE.md) |
| TASK-020 | [Крафт топора — ещё в разработке](docs/TASK-020_STONE_AXE_CRAFTING_DEV.md) |

Рекомендуемый порядок чтения: **[PROJECT_STATUS](docs/PROJECT_STATUS.md) → [HANDOFF](docs/HANDOFF_NEXT_CHAT.md) → нужная TASK-документация**.
