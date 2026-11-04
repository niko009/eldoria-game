# TASK-060 — исключение отправки частых снимков закрывающимся WebSocket-клиентам

**Ветка:** `feature/TASK-059-class-ability-vfx` (после TASK-059). **Production не менялся.**

## Причина

Раньше `wolf_snapshot.rpc`, `pack_wolf_snapshot.rpc` и `passive_snapshot.rpc` рассылались всем клиентам каждые 150–300 мс. Во время WebSocket close-handshake клиент может уже находиться в `STATE_CLOSING`, но `peer_disconnected` на Godot-сервере ещё не обработан. В этот момент широковещательная RPC вызывает `Condition "ready_state != STATE_OPEN"` в `wsl_peer.cpp` (наблюдалось в `tests/run_websocket_e2e.sh`, backtrace `_tick_passive_creatures`, `_combat_server_tick`).

## Реализация

- `_ready_snapshot_peers` на сервере: для WebSocket сверяет `WebSocketMultiplayerPeer.get_peer(id).get_ready_state()` с `WebSocketPeer.STATE_OPEN`; для ENet использует стандартный список `multiplayer.get_peers()`.
- Высокочастотные обновления **одиночного волка, стаи и пассивных животных** посылаются `rpc_id` только открытым соединениям.
- Локальное обновление животных у host-клиента и исходная серверная физика не меняются.
- **Область исправления ограничена частыми snapshot-RPC.** Другие редкие broadcast RPC ещё могут потребовать аналогичной защиты при стресс-тесте переподключений.

## Проверки

- Три последовательных запуска `bash tests/run_websocket_e2e.sh`: **3/3 PASS** после изменения. В каждом запуске сервер WebSocket + два отдельных клиента; движение, взаимодействие, переподключение.
- Полный набор `bash tests/run_dev_gameplay_e2e.sh` с TASK-059, TASK-057/058 и TASK-011–056 остаётся обязательным перед релизом.
- Физический Android/WSS public endpoint в этой ветке ещё не проверялся, выпуск релиза не выполняется.
