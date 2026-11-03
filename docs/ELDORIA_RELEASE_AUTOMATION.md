# Eldoria — однокомандная сборка и публикация (TASK-027 Release Automation)

**Скрипт:** `scripts/release_eldoria.sh`. Он выполняется **на bacus-server** с один раз установленными Godot 4.5.2, Android SDK/JDK и экспортными шаблонами. Не требует GitHub Actions или ежемесячного CI-сервиса.

После первого развёртывания скрипт устанавливается в `/usr/local/bin/eldoria-release`. Пример:

```bash
# Проверить/собрать без изменения production:
sudo eldoria-release 0.5.11 release/eldoria-v0.5.11 --build-only

# Одной командой собрать Android APK, Windows ZIP, проверить и выпустить:
sudo eldoria-release 0.5.11 release/eldoria-v0.5.11 --deploy
```


Здесь `0.5.11` — **пример следующей версии**; перед запуском должна существовать проверенная ветка `release/eldoria-v0.5.11`.

## Что происходит автоматически

1. Проверяет текущую версию из `server.json` и `latest.json`, наличие инструментов, подпись, состояние API и Godot. Ставит `flock` — параллельные релизы невозможны.
2. Клонирует **указанную GitHub-ветку** в новую архивируемую папку `/srv/bacus/apps/eldoria-releases/<version>-<UTC>/repo`, фиксирует исходный SHA. Исходную ветку не изменяет.
3. В изолированной копии выставляет `CLIENT_VERSION`, Android `versionName` и увеличивает `versionCode` на 1 относительно прошлого APK. Выполняет базовые Godot tests.
4. Собирает и проверяет **подписанный Android ARM64 APK** и Windows x64 ZIP. Android подпись должна строго совпадать с предыдущим релизом. Manifest `latest.json` генерируется **только из реальных файлов**, SHA256 и размер читаются из артефактов.
5. В режиме `--deploy` сохраняет snapshot публичных метаданных, systemd drop-ins и `pg_dump -Fc` мира в `/srv/bacus/backups/eldoria-pre-<version>-<UTC>/`.
6. Публикует новые файлы без удаления старых, переключает **тот же production Godot-сервер на новую версию**, затем обновляет `server.json`, `latest.json` и HTML-страницу. .NET Persistence API и PostgreSQL schema **не меняет**.
7. Проверяет сервисы, публичную версию через HTTPS и **полную загрузку APK с SHA256**; при ошибке после переключения восстанавливает старую конфигурацию/метаданные и перезапускает прежний Godot.
8. Пишет подробный лог и исходный SHA в директорию выпуска. После успешной публикации рекомендуются внешний WSS smoke и 2 физических Android теста; запуск на реальных устройствах скрипт не имитирует.

## Границы / безопасность

- Этот скрипт только для **совместимых клиент+Godot** изменений без миграций SQL или нового приватного API. Если нужны SQL/.NET изменения, применять **отдельный согласованный production-plan**, а не скрыто включать их в скрипт.
- Не хранить keystore и приватные ключи в GitHub! Android debug-keystore на bacus-server находится в `/home/mbacus/.local/share/godot/keystores/debug.keystore` с правами 600. Подпись используется **та же**, что у v0.5.4, иначе обновление APK поверх предыдущего Android не установится.
- Build-only не изменяет production. `--deploy` — явное разрешение на публикацию.
- При проблеме после релиза откатываются **метаданные сайта и Godot**, но **никогда автоматически PostgreSQL**, чтобы не стереть прогресс игроков.
- Пакет инструментов для первичной установки переносится на сервер защищённым отдельным способом, не кладётся в repo, не публикуется на сайте. Последующие релизы используют установленные SDK и шаблоны.
- Скрипт делает быстрые серверные smoke-тесты. Полная `bash tests/run_dev_gameplay_e2e.sh` и проверка на реальных Android должны проводиться как release gate **до** вызова `--deploy`.
- Следующий шаг для production: измерить FPS и 5%-low на реальных Android v0.5.10 в лесу, у костра и во время ночной атаки. На v0.5.8 был лишь один замер 22,8 FPS avg и 16,4 FPS 5%-low; новые FPS численно не подтверждены.

## Локальные правила

- Godot 4.5.2 GL Compatibility; Android `arm64-v8a`, пакет `dev.bacus.eldoria`.
- Отладочная подпись используется только для тестовых APK и внутренней раздачи; для Google Play требуется отдельная безопасная политика подписания и действующий правообладатель аккаунта.
- Production URL: `https://bacus.dev/projects/eldoria/`; WSS `wss://bacus.dev/eldoria/ws`.

## Исправления после перехода v0.5.9 → v0.5.10 (3 ноября 2026)

**Использовать актуальную версию скрипта из `release/eldoria-v0.5.10`**, deployed source SHA `37b2c3ea4c0f2f7f0af0f6c9443f061820171f45`. На bacus-server обновлён `/usr/local/bin/eldoria-release`.

Два реальных дефекта обнаружились при проверяемом выпуске v0.5.10:

1. **Приоритет systemd drop-ins.** Старое имя `v0510-release.conf` сортируется раньше `v059-release.conf` (сортировка **лексикографическая**, не числовая). При первой попытке скрипт обнаружил, что `ExecStart` указывает на v0.5.9, и выполнил `RELEASE_FAILED, AUTO_ROLLBACK`. Исправлено постоянным именем `/etc/systemd/system/eldoria-ws-test.service.d/zz-eldoria-release.conf`; перед переключением проверяется `systemctl show ... -p ExecStart`. При откате скрипт возвращает прежнюю копию **этого же** drop-in из backup, если он существовал, либо удаляет созданный впервые. **Не возвращать схему `v${VERSION//./}-release.conf`**.
2. **Ложный SIGPIPE (код 141) при проверке валидного pg_dump.** С `set -o pipefail` вызов `docker exec ... pg_restore -l | grep -q 'eldoria_worlds'` может завершать `pg_restore` через SIGPIPE, так как `grep -q` закрывает поток при раннем совпадении. Вторая попытка остановилась на backup, **не затронув production**. Теперь `pg_restore -l` полностью записывается в `$BACKUP/world.pg.list`, а поиск выполняется в готовом файле; порт проверяется через `ss -lnt | grep -F ':7788' >/dev/null` (без раннего `-q`).

**Итог третьей попытки:** `ELDORIA_RELEASE_SUCCESS 0.5.10`; `BUILD_PASS`, `CERT_MATCH`, `BACKUP_PASS`, `NEW_GODOT_SERVICE_UP`, `PUBLIC_VERSION_PASS`, `PUBLIC_APK_SHA256_PASS`. Затем отдельно **PASS** публичный WSS с двумя клиентами и внешнее скачивание APK/ZIP с проверкой SHA. [Подробный отчёт](RELEASE_0510_COOP.md).

**Важное правило:** `--build-only` и `--deploy` выполняют **отдельные сборки**; их архивные SHA бинарников могут отличаться, даже если Git source одинаков. Единственными контрольными суммами опубликованной v0.5.10 являются суммы из `docs/RELEASE_0510_COOP.md` / текущего `latest.json`, а не из предыдущего `--build-only`.

**Архивные каталоги v0.5.10:**
- Успешный checkout: `/srv/bacus/apps/eldoria-releases/0.5.10-20261103T113252Z/repo`.
- Backup: `/srv/bacus/backups/eldoria-pre-0.5.10-20261103T113252Z/`, в нём `world.pg.dump`, `world.pg.list`, предшествующие site метаданные и systemd drop-ins.
- Старые v0.5.9 APK/Windows остаются на сайте; восстановление **старой БД автоматически запрещено**, иначе можно потерять новые предметы и постройки пользователей.

**Минимальный gate каждого будущего релиза:** (1) на отдельной feature-ветке пройти `bash tests/run_dev_gameplay_e2e.sh`, при сетевых изменениях — 2-клиентный E2E и при persistence изменениях — тест в изолированной PostgreSQL; (2) сверить SHA дерева и GitHub release branch; (3) `--build-only`; (4) `--deploy`; (5) независимые проверки public WSS с двумя клиентами, двух скачанных артефактов по SHA, `server.json`, `latest.json`, состояния systemd и записи `PERSISTENCE LOADED`.
