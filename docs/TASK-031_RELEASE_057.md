# Eldoria v0.5.7 — исправление Android-прокрутки меню

**Дата:** 3 ноября 2026 г. **Статус:** опубликована, серверная и внешняя проверка PASS.  
**Исходный код:** `e3b717a8bae9568b02e5008a67cdf69a151c3f5d` (`TASK-030`), от v0.5.6.

## Что исправлено
- Жесты вертикальной прокрутки в Android landscape: «Настройки», «Рюкзак», «Строительство», «Крафт».
- При свайпе по кнопкам меню больше не исполняются их действия при отпускании пальца.
- Короткие тапы по кнопкам продолжают работать. Вкладки, hotbar, джойстик и 3D-управление не изменены.
- Реализация: [TASK-030_ANDROID_MODAL_SCROLL.md](TASK-030_ANDROID_MODAL_SCROLL.md). Ключевые файлы: `client/ui/touch_scroll.gd`, `client/ui/live_ui.gd`, `client/ui_preview/ui_preview.gd`.
- Новая регрессия: `client/tests/android_modal_scroll_e2e.gd`, добавлена в `tests/run_dev_gameplay_e2e.sh`.

## Выкладка
- `sudo eldoria-release 0.5.7 release/eldoria-v0.5.7 --deploy` (с публичными описаниями изменений).
- Production checkout: `/srv/bacus/apps/eldoria-releases/0.5.7-20261103T071849Z/repo`.
- Backup: `/srv/bacus/backups/eldoria-pre-0.5.7-20261103T071849Z/` (содержит `world.pg.dump`, метаданные сайта, systemd overrides).
- PostgreSQL schema/.NET API не менялись; Godot загрузил прежний мир: `profiles=5`, `depleted=114`. Старые APK/ZIP v0.5.6 сохранены.

## Артефакты

| Файл | Размер | SHA-256 |
|---|---:|---|
| `Eldoria-0.5.7-debug.apk` | 38 826 053 байт | `9969c5d285588248d492696330fa4990d88999b2683131933c2200a2e5d0a9bf` |
| `Eldoria-Windows-0.5.7.zip` | 44 725 649 байт | `2fb40064773a5a50d8d0137f53877202c68c4197d757eecd5713914f06fd47b0` |

APK: `dev.bacus.eldoria`, `versionName=0.5.7`, `versionCode=18`, подписан прежним сертификатом.

## Фактические проверки

- Старый v0.5.6: симулированный Android `InputEventScreenDrag` поверх кнопки на 800×360 **FAIL**: список не движется.
- Новый код: настройки, инвентарь, строительство и крафт, свайп вниз/вверх, запрет случайных нажатий и проверка обычного тапа **PASS**. UI Preview **PASS**.
- Полный `tests/run_dev_gameplay_e2e.sh`: **PASS, exit 0** — Godot import, ENet/WS с двумя клиентами, крафт, сбор, бой, сохранение, Android joystick, OpenGL.
- Встроенный production release gate: четыре Godot smoke, сборка Android/Windows, подпись и SHA256 **PASS**.
- Публичные `server.json` и `latest.json`: `0.5.7`; Godot WS и .NET API active.
- Публичный WSS: самостоятельный клиент и два независимых клиента, движение, взаимодействие и переподключение **PASS**.
- APK и Windows ZIP полностью скачаны **по внешнему HTTPS**: обе SHA256 совпадают.
- **Не проверено на реальном Android:** необходимо установить APK v0.5.7 на оба телефона и провести длинный свайп в настройках, рюкзаке и крафте. Linux touch simulation не заменяет аппаратный тест.
