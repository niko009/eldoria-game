# TASK-004 — автоматическое подключение к серверу Eldoria (2026-11-01)

## Поведение
- Одна кодовая база Godot для Android/Windows; при обычном запуске клиент без ввода IP делает HTTPS GET `https://bacus.dev/projects/eldoria/server.json`.
- Серверный JSON берётся из репозитория `niko009/bacus.dev`, файл `public/projects/eldoria/server.json`.
- Проверяются `schema=1`, `protocol=godot-enet`, `client_version=0.1.2`, `status`, допустимый IP/host и UDP port.
- При валидном ответе создаётся ENetMultiplayerPeer клиент к найденному адресу; при ошибке/таймауте пользователь видит ошибку и кнопку **Connect / Retry**. IP-поле не показывается.
- Смена адреса сервера не требует перевыпускать APK/EXE: поправить серверный JSON. Смена сетевого протокола требует новой версии и совместимости.
- `ELDORIA_CONFIG_URL` — override только для тестовых запусков разработчика. Не встраивать приватные ключи в JSON: он **публичный**.
- `status=lan` означает **игроки должны находиться в той же сети**. HTTPS служит только для обнаружения адреса; игровые пакеты идут напрямую ENet UDP 7777, Cloudflare Tunnel HTTP не обеспечивает WAN UDP.
- Отсутствует Internet multiplayer до настройки защищённого публичного UDP-роутинга и аутентификации. Нельзя объявлять игру доступной извне.

## Серверный документ (на 2026-11-01)
```json
{
  "schema": 1,
  "protocol": "godot-enet",
  "client_version": "0.1.2",
  "status": "lan",
  "host": "192.168.1.88",
  "port": 7777
}
```

## Тесты
- `bash tests/run_discovery_e2e.sh`: HTTP provider + отдельный Godot-сервер и 2 разных Godot-процесса. Клиенты обнаруживают IP автоматически, проходят двустороннюю синхронизацию движения, Wave, disconnect, повторное получение адреса и reconnect.
- `bash tests/run_network_e2e.sh`: существующий host/client не сломан.
- `bash tests/run_dedicated_e2e.sh`: отдельный headless server + 2 clients не сломан.
- `bash tests/build_windows.sh` и `bash tests/build_android_debug.sh`: Windows ZIP и подписанный Android APK.
- Live smoke на bacus-server: новый Godot-клиент прочитал **публичный HTTPS server.json** и реально подключился к работающему Godot ENet UDP 7777 — **PASS**.
- Windows ZIP 0.1.2: 33 787 086 байт, SHA-256 `b1f6eaf52d82c7ef5b652e020e49dc7c19547a3e485c3892d105960b59ef5335`.
- Android APK 0.1.2: 27 718 906 байт, SHA-256 `fa75c1a247ca0f594d197e715d6139ad135a057bfea6a6651292ac0693862f4f`.
- На реальных Windows/Android устройствах запуск **ещё не проверялся**.

## Бэклог
1. Проверка реальных Windows и Android в одной LAN; замер времени discovery/connection, сенсорного ввода, UX ошибок.
2. Отдельная конфигурационная API с живым состоянием сервера; текущий статический JSON не отражает фактический статус процесса.
3. Настоящий публичный UDP-маршрут с security/anti-cheat или альтернатива WebSocket/TCP; согласовать транспорт для будущего авторитетного .NET.
