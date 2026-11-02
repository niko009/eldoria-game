# TASK-021C — Eldoria v0.5.3 production release (UI)

**Дата:** 2 ноября 2026. **Статус:** опубликовано и проверено.  
**Исходники:** `feature/TASK-021B-ui-integration` (основана на Codex TASK-021A commit `fb451a6e`).  
**Публичная страница:** https://bacus.dev/projects/eldoria/

## Состав релиза
- Реальный HUD с подключением к игровому статусу и серверному инвентарю; панель быстрого доступа, рюкзак.
- Обновлённые меню костра и палатки; 3D-предпросмотр места, создание через прежнюю серверную проверку. Touch-джойстик и кнопки сбора/прыжка/бега.
- Настройки графики, звука, телеметрии, выбора персонажа, подключения и отключения.
- Меню крафта каменного топора **показывает недоступность**: незавершённая TASK-020, PostgreSQL-миграция не применялась.
- Dedicated Godot использует те же данные/протокол, что v0.5.2. Изменения только в клиенте/UI и версии согласования. Приватный .NET 10 API и PostgreSQL 16 **не менялись**.

## Реальные проверки
- Godot 4.5.2: импорт и запуск сцены без ошибок; `live_ui_smoke.gd` PASS локально и в staging на сервере.
- Полный `tests/run_dev_gameplay_e2e.sh`: PASS — ENet, dedicated, WebSocket, ресурсная добыча, строительство, переподключение, сохранение, графические проверки (headless/Xvfb). Это **не** физический Android тест.
- Подписанный Android ARM64 APK (versionCode 14, versionName 0.5.3), сертификат SHA-256 совпал с v0.5.2.
- Windows x64 ZIP с EXE/PCK, локальная проверка структуры и PE x64 PASS.
- Production: новая конфигурация HTTPS `server.json` и `latest.json` вернула 0.5.3; Godot service active.
- **После публикации** реальный публичный WSS: клиент получил конфигурацию и присоединился; 2 независимых клиента прошли движение, Wave, disconnect/reconnect (оба exit code 0).
- Публичная загрузка **обоих** артефактов заново через HTTPS с последующим SHA256: PASS. Клиент отправил синтетическую тестовую телеметрию через публичный WSS (успешная отправка, не доказательство серверного хранения).

## Артефакты
| Платформа | Файл | Размер (bytes) | SHA-256 |
|---|---|---:|---|
| Android ARM64 (debug signed) | `Eldoria-0.5.3-debug.apk` | 36,961,098 | `5274f48cd9f008945664ae0286285b1e777af1c820b353b2fdc66e423b7be83c` |
| Windows x64 | `Eldoria-Windows-0.5.3.zip` | 42,865,201 | `cd9b91717234aeef16400af0dc3ffeafad6080e725d73bd4d8e1214993e38f76` |

## Развёртывание и откат
- Public site files: `/srv/bacus/apps/bacus-dev/site/projects/eldoria/`.
- Godot dedicated service: `eldoria-ws-test.service`, клиент из `/srv/bacus/apps/eldoria-v053-staging/repo/client`; override: `/etc/systemd/system/eldoria-ws-test.service.d/v053-ui.conf`.
- Backup pre-release: `/srv/bacus/backups/eldoria-pre-053-20261102-1659/` (прежние index.html, server.json, latest.json, systemd unit и drop-ins). Старые v0.5.2 APK/ZIP сохранены.
- Откат: вернуть три сайта файла из backup, удалить override `v053-ui.conf`, `systemctl daemon-reload`, перезапустить Godot; **не восстанавливать БД** (схема и данные не изменялись).

## Ограничения
- Физические Android touch-тесты, пользовательская визуальная оценка на реальных устройствах и достоверный real-device FPS ещё нужны.
- Мини-карта, здоровье, квесты, сражения, NPC и работающее изготовление топора в текущей игре отсутствуют.
- Код Codex использует композицию варианта D и нативные Godot Control, но точное совпадение с концептуальным изображением не подтверждено аппаратным визуальным тестом.
