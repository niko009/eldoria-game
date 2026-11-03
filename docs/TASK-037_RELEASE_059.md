# Eldoria v0.5.9 — Android performance optimization release

**Дата:** 3 ноября 2026 (UTC). **Статус:** RELEASED, production и public network smoke PASS.

**Развёрнутый исходный commit:** `4332dd4cdc4b9f158af82f7a6fd04b863194c9bc` (ветка `release/eldoria-v0.5.9`); предыдущий production `v0.5.8`.

## Почему понадобилась оптимизация

Последний Android-запуск v0.5.8 в 10:11:19 UTC оставил один отчёт в PostgreSQL `eldoria_telemetry`: **Low, FPS avg=22.8, 5%-low=16.4, p95 frame=61.1 мс, RTT=111 мс**. Godot и .NET API активны, ошибок API за проверенные последние 3 часа не было. Одного отчёта недостаточно, чтобы доказать GPU/CPU причину.

## Что поменяли

- `client/forest_world.gd`: пространственная сетка 12×12 м для статичных деревьев/камней. `collides_at`, `_sweep_hits` и `camera_safe_target` вместо перебора всех объектов исследуют только пересекающиеся ячейки. Порядок объектов сохранён, динамическая активность срубленных деревьев проверяется в запросе.
- `client/main.gd`: обновление только информационных подсказок о соседних ресурсах/костре раз в 200 мс вместо каждого кадра, а серверные проверки условий крафта и добычи остались мгновенными.
- `client/tests/task037_collision_benchmark.gd`: 2500 проверок parity против оригинального полного перебора и 150 сравнений перемещения — PASS. На одном и том же Godot headless компьютере CPU microbench sweep-запросов: **599 983 мкс → 29 881 мкс (20.08×)**. Это только этот CPU участок и **не доказательство роста FPS Android**.
- Не изменяли RNG, идентификаторы ресурсов, размещение мира, шейдеры, текстуры, размеры коллизий, сетевой API, SQL и .NET.

Подробный технический отчёт: [TASK-037_ANDROID_PERFORMANCE.md](TASK-037_ANDROID_PERFORMANCE.md).

## Публикация

`sudo eldoria-release 0.5.9 release/eldoria-v0.5.9 --deploy`.

- Production checkout: `/srv/bacus/apps/eldoria-releases/0.5.9-20261103T103501Z/repo`.
- Backup: `/srv/bacus/backups/eldoria-pre-0.5.9-20261103T103501Z/`, включая проверенный `world.pg.dump` и предыдущие systemd/сайт-метаданные.
- После рестарта: `ELDORIA PERSISTENCE LOADED profiles=5 depleted=116`; старый мир/прогресс не сбрасывался.
- `eldoria-ws-test.service` и `eldoria-persistence.service` — active.
- Клиент и новый Godot dedicated используют одну версию 0.5.9. Старые APK/ZIP v0.5.8 сохранены.

## APK / Windows

| Платформа | URL/файл | Байты | SHA-256 |
|---|---|---:|---|
| Android ARM64 debug | `Eldoria-0.5.9-debug.apk` | 38 850 923 | `e1e86e09e3ba1d866ae1c4e2f5e2ec21123e1e895e30aae96141f6dcc8eccb0f` |
| Windows x64 | `Eldoria-Windows-0.5.9.zip` | 44 749 038 | `68c99c1a973f5c391e62c49e28cdcf9441950b29e954ed07aa148859de5ff8b4` |

APK `dev.bacus.eldoria`, `versionName=0.5.9`, `versionCode=20`; Android signer совпал с прежним релизом. Оба файла полностью скачаны через внешний HTTPS из среды Local Coder, SHA совпали.

## Приёмка

- **PASS** Godot import, 4 встроенных smoke-теста, Android/Windows builds, Android signing, проверка manifests и публичного APK.
- **PASS** полный `tests/run_dev_gameplay_e2e.sh`: ENet/WS с двумя клиентами, collision/camera parity, полноценные крафт/строительство/бой, сохранение, UI/Android joystick и OpenGL.
- **PASS** публичный WSS: отдельный клиент; два независимых клиента: движение, взаимодействие и disconnect/rejoin.
- **PASS** публичные `latest.json`, `server.json` и оба файла со своими SHA256; действующие сервисы; backup.
- **НЕ ПРОВЕРЕНО** Android FPS на v0.5.9, температура, длительность стабильной игры. Стабильность 30 FPS/60 FPS **не заявлена**.

## Следующий шаг (TASK-038)

Сравнить новый Android Low v0.5.9 с предыдущим `22.8 FPS / 16.4 5%-low` в тех же местах/условиях минимум 3 минуты: лагерь, лес, озеро. Если FPS остаётся низким — включить «Настройки → Диагностика FPS» и проверить CPU/Physics vs draw calls; следующий performance pass должен быть по подтверждённому GPU hotspot. До мобильного сравнения не добавлять тяжёлых визуальных эффектов.
