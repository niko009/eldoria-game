# Eldoria v0.5.6 — production release

**Дата:** 3 ноября 2026 г.  
**Статус:** опубликована и проверена на сервере; физический Android-тест ожидается.  
**Codex head (точный source SHA в deployed checkout):** `18b2ba161bbc2c8cb1b6cb2d971f93d12bbfda1f`.  
**Входящие коммиты:** `cdce8ff` (дальнее окружение и shaders), `72680c1` (лагерь), `18b2ba1` (текстура луга High).

## Состав релиза

- Дальние горы и хвойный лес на основе сцены `client/alpine_scenery.gd`. Декоративный слой не меняет RNG генерации ресурсных ID.
- Шейдеры неба, земли, пруда, анимированного костра, отключаемые в Low; High использует дополнительные декоративные материалы и отложенно загружаемую оригинальную текстуру луга.
- Палатка с тканевыми складками, входом, полом, швами, растяжками; костёр с обновлённым визуалом. Footprint построек не менялся.
- Все функции v0.5.5 (мультиплеер WSS, сбор ресурсов, крафт, топор, PvE волк, HP, HUD, F9) сохранены.
- **Без миграций SQL и изменений .NET persistence API.** При старте нового Godot-сервера: `profiles=5`, `depleted=111` (существующий мир загружен, без сброса).

## Автоматическая публикация

```bash
sudo eldoria-release 0.5.6 release/eldoria-v0.5.6 --build-only
sudo eldoria-release 0.5.6 release/eldoria-v0.5.6 --deploy
```

Первый запуск собрал и проверил артефакты **без изменения production**; второй создал backup, повторно собрал файлы, сверил подпись и метаданные, переключил сервер и сайт, проверил публичный APK по SHA256.

Production source: `/srv/bacus/apps/eldoria-releases/0.5.6-20261103T064617Z/repo`.  
Backup: `/srv/bacus/backups/eldoria-pre-0.5.6-20261103T064617Z/` (PostgreSQL `pg_dump -Fc`, метаданные сайта и systemd drop-ins). Старые APK/ZIP доступны, DB автоматически не откатывается.

## Артефакты

| Файл | Байты | SHA-256 |
|---|---:|---|
| `Eldoria-0.5.6-debug.apk` | 38 821 808 | `14a331a4ec6d21344927d6b918b54b30b146e4f3760e2ccdc347955f812024fd` |
| `Eldoria-Windows-0.5.6.zip` | 44 722 940 | `f0b8a7fc1ea23cde6f41a973eccc95ac4d8bfbe187df15ab126147ae3468733e` |

APK: `dev.bacus.eldoria`, `versionName=0.5.6`, `versionCode=17`, arm64-v8a. Android signing certificate совпал с v0.5.5.

## Проверки

- **PASS:** Godot 4.5.2 import и четыре smoke-сценария (live UI, UI preview, overlay диагностики, первый бой) на сервере.
- **PASS:** полный игровой E2E из frozen `18b2ba1` на Local Coder, exit=0: ENet, WebSocket 2 клиента, avatar/jump, resource/строительство/крафт/бой, сохранение, joystick, OpenGL MultiMesh.
- **PASS:** production `server.json` и `latest.json` содержат 0.5.6; WSS Godot и .NET API активны.
- **PASS:** production WSS: один клиент и два независимых клиента (движение, взаимодействия, отключение/возврат).
- **PASS:** полная внешняя загрузка Android APK и Windows ZIP с `https://bacus.dev`, повторная SHA256 проверка обеих файлов.
- **НЕ ПРОВЕРЕНО:** две физических Android после новой графики, реальная частота кадров и нагрев устройств. Исходные падения до 13 FPS нельзя считать исправленными до тестов.

Следующий шаг: после установки v0.5.6 выполнить сценарии из [TASK-026V_DEVICE_TEST_PLAN.md](TASK-026V_DEVICE_TEST_PLAN.md) на двух Android (Low/High, лагерь/лес/озеро).
