# Eldoria v0.5.5 — production release & automated build

**Дата:** 2 ноября 2026 года (UTC). **Статус:** RELEASED / checks PASS.

## Результат
- Новая стилизация мира TASK-026V (лес, освещение, озеро, горы), переработанный UI TASK-025B, локальный debug overlay F9, первый боевой цикл TASK-025 (волк, HP, смерть/возрождение).
- Публичные Android APK и Windows ZIP версии **0.5.5**, Android `versionCode=16`, прежняя подпись `dev.bacus.eldoria`.
- Godot dedicated server обновлён на совместимый с клиентами код. PostgreSQL schema и .NET Persistence API не менялись. Существующий мир сохранён: при старте сервер сообщил `profiles=5 depleted=108`.
- Исходный SHA развёрнутой рабочей копии: `416b0980844667f1890af05374ac0ec91869f5e4` (автоматизация позже уточнена в release branch без пересборки клиента). Codex visual commits включены: `b39fd2f`, `0fd924b`.
- Один вызов на сервере: `sudo eldoria-release 0.5.5 release/eldoria-v0.5.5 --deploy`.

## Файлы и проверенные SHA-256
| Платформа | Артефакт | Байты | SHA256 |
|---|---|---:|---|
| Android ARM64 debug | `Eldoria-0.5.5-debug.apk` | 36990209 | `e8522adb77c920681b57a84717b0b7a5b248b264d24e5df8662150c2e0a2bfc0` |
| Windows x64 | `Eldoria-Windows-0.5.5.zip` | 42891070 | `354a3b716ed2b68875cfd585938711161d8550d64f0d88661a88137fa6623b57` |

Оба файла повторно скачаны по публичному HTTPS извне сервера и прошли SHA256. `server.json` и `latest.json` содержат 0.5.5.

## Проверки
- **PASS**: полный игровой Godot E2E на зафиксированном последнем Codex commit — ENet, два WebSocket-клиента, UI, крафт, бой, анимация, сохранение и OpenGL.
- Первый сетевой прогон E2E дал нестабильность в момент взаимодействия клиента A; отдельный повторный тест и **полный** повтор на последней ветке PASS. Факт зафиксирован, причинный баг не доказан.
- **PASS**: серверный импорт Godot + 4 отдельных smoke-теста UI/Preview/диагностики/боя до сборки.
- **PASS**: собранные APK/ZIP, Android apk signature и versionCode increment; Android cert совпадает с v0.5.4.
- **PASS**: production Godot и .NET API active, восстановлен мир из базы, 0 OOM в ходе выпуска.
- **PASS**: публичный WebSocket тест отдельным клиентом; два подключённых клиента, движение, взаимодействие, разрыв/переподключение — PASS после релиза.
- **НЕ ПРОВЕРЕНО**: физические Android устройства, термонагрузка, FPS после графического изменения. Нельзя утверждать, что падение до 13 FPS исправлено.

## Повторяемая автоматизация и откат
- Сценарий в репозитории: `scripts/release_eldoria.sh`, установлен на сервере как `/usr/local/bin/eldoria-release`. Инструкция: [ELDORIA_RELEASE_AUTOMATION.md](ELDORIA_RELEASE_AUTOMATION.md).
- `--build-only`: без переключения production. `--deploy`: сборка Android и Windows, проверки подписи, backup, установка артефактов, перезапуск игрового сервера и проверка HTTPS/SHA.
- Source под production `/srv/bacus/apps/eldoria-releases/0.5.5-20261102T201951Z/repo`.
- Backup `/srv/bacus/backups/eldoria-pre-0.5.5-20261102T201951Z/` (до выпуска: SQL `pg_dump -Fc`, index.html, latest.json, server.json, systemd drop-ins). Старые APK v0.5.4 и Windows ZIP сохранены.
- При ошибке после переключения скрипт восстанавливает старые метаданные, прежний Godot override и сервис; **PostgreSQL автоматически не откатывается**, чтобы не потерять прогресс.
- Однократный набор инструментов Android/JDK и исходный keystore переданы защищённо, установлены с приватными правами. Временный канал передачи отключён и пакет удалён.
