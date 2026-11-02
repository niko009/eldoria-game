# Eldoria v0.5.4 — проверенный production release

**Дата:** 2 ноября 2026 г.  
**Источник:** `feature/TASK-022-stone-axe-live-ui`, HEAD `d496aef0568bd11280d8e761452bc205dfdade08` (полный tree из проверенной локальной сборки).  
**Production:** `https://bacus.dev/projects/eldoria/`.  
**Статус:** опубликовано; автоматические production smoke и SHA256 PASS.

## Изменения
- TASK-022: каменный топор, крафт около костра за 2 древесины и 2 камня, один топор на игрока, серверная валидация, защита от дубликатов.
- TASK-023: выбор топора в четвёртом слоте или инвентаре, подтверждение экипировки сервером, 2 дерева за удар только с экипированным топором. Переключение на другой предмет снимает топор. Экипировка сессионная и сбрасывается при переподключении; топор сохраняется.
- Аддитивная PostgreSQL миграция `003_stone_axe.sql`: `eldoria_players.axe` = 0 по умолчанию, `CHECK (axe BETWEEN 0 AND 1)`. Старые профили совместимы, анонимная авторизация не менялась.
- Новые компоненты встроены в UI v0.5.3, Android и Windows сборки согласованы с Godot/JSON-манифестом версии 0.5.4.

## Выполненные проверки

| Проверка | Результат |
|---|---|
| Godot 4.5.2 импорт и UI smoke | PASS на Local Coder и staging сервере |
| Локальные игровые ENet и WebSocket тесты | PASS; полная регрессия со второго прогона |
| Крафт, запрет повторного крафта, экипировка чужого/отсутствующего топора | PASS; сервер + 2 независимых WebSocket-клиента |
| Сохранение топора и восстановление | PASS на JSON и изолированной PostgreSQL (.NET API, Npgsql) |
| Отказ сохранения, откат расходов, последняя единица древесины | PASS (fault-injection) |
| Android ARM64 debug APK / Windows x64 ZIP | PASS, сборки |
| Сертификат Android v0.5.3 → v0.5.4 | SHA256 сертификата совпал |
| Production миграция и новый приватный API | PASS, `/health` + чтение world |
| Production Godot dedicated WSS | PASS, загружен существующий мир: 3 профиля, 21 изменённый ресурс |
| Production online: подключение, два клиента, движение, взаимодействие, reconnect | PASS |
| Публичное скачивание APK и ZIP, повторная SHA256 проверка | PASS |
| Публичные `server.json` / `latest.json` | 0.5.4 / 0.5.4 |

**Известное ограничение:** сборка v0.5.4 ещё не протестирована на физическом Android пользователем. Старый WebSocket E2E один раз дал нестабильный результат при параллельной сборке; полный повторный прогон PASS. Production тест нового крафта непосредственно на реальном пользовательском прогрессе не проводился — проверен изолированный PostgreSQL и WSS с двумя клиентами.

## Публичные файлы

| Файл | Размер, байт | SHA256 |
|---|---:|---|
| `Eldoria-0.5.4-debug.apk` | 36 965 194 | `cbd1bcfde6eae3dde842e0a753df3c4cfd2b137fdc43b87244e6b3d61aa4fbc3` |
| `Eldoria-Windows-0.5.4.zip` | 42 869 508 | `c8832b97bf4e3cdce7a5abf89ca65a85d467ce124f92f224a5baeaa44b69654f` |

Самостоятельный .NET 10 API Linux binary: `c1fec4f2c5568e9e53283e3db29b25bc3ddb5d586743f3d896f6a660041a100e`.

## Публикация и восстановление

- Godot source: `/srv/bacus/apps/eldoria-v054-staging/repo/client`.
- Service: `eldoria-ws-test.service`, override `/etc/systemd/system/eldoria-ws-test.service.d/v054-craft.conf`.
- Приватный API: `/srv/bacus/apps/eldoria-persistence/Eldoria.Persistence`, service `eldoria-persistence.service`.
- Публичные файлы: `/srv/bacus/apps/bacus-dev/site/projects/eldoria/`.
- **Backup до изменений:** `/srv/bacus/backups/eldoria-pre-054-20261102T174536Z/`. Содержит production `pg_dump -Fc` (проверен через `pg_restore -l`), прежний .NET binary, `server.json`, `latest.json`, `index.html`, конфигурации systemd. APK и ZIP v0.5.3 сохранены на сайте.

**Откат при необходимости:** сначала остановить Godot и API; вернуть прежний API binary из backup; удалить новый override `v054-craft.conf`, выполнить `systemctl daemon-reload`, перезапустить API и Godot; восстановить `server.json`, `latest.json` и `index.html` из backup; проверить публичный WSS и старые клиенты. Не удалять `axe` из PostgreSQL и не делать автоматический restore старого дампа, иначе будут потеряны новые изменения в мире. Важно: старый API v0.5.3 не сохраняет поле `axe`; после отката старые сохранения могут обнулить новые топоры. Перед откатом нужно учитывать свежий прогресс игроков и его миграционную совместимость.
