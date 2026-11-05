# Godot MCP — использование в разработке Eldoria

## Текущее окружение (проверено 2026-11-05)
Godot Editor MCP `2026.10.20.1` установлен в Linux-контейнере **Local Coder**. Godot `4.5.2`; транспорт HTTP `127.0.0.1:9090/mcp`, WebSocket bridge `127.0.0.1:9080`. **Оба адреса только localhost; не публиковать в сеть.**

Инструкция эксплуатации, настройки и результаты практических тестов уже находятся **в контейнере**, вне этого репозитория:
`/home/coder/.local/share/eldoria-godot-mcp/USAGE.md`.
Путь может отличаться на другом агенте/машине; при отсутствии директории нужно проверить окружение, а не предполагать работающий MCP.

Сейчас MCP подключён к **изолированной копии** проекта:
`/home/coder/.local/share/eldoria-godot-mcp/smoke-latest`.
Она может отставать от рабочей ветки. Не считать её источником актуального кода и **не синхронизировать автоматически в рабочий репозиторий**.

## Быстрый запуск из Local Coder
```bash
BASE=/home/coder/.local/share/eldoria-godot-mcp
"$BASE/start.sh"
"$BASE/mcp_cli.py" call godot_health_check
"$BASE/mcp_cli.py" call godot_inspection_get_project_info
"$BASE/mcp_cli.py" call godot_inspection_get_active_scene
"$BASE/mcp_cli.py" call godot_inspection_get_scene_tree
"$BASE/mcp_cli.py" list
"$BASE/mcp_cli.py" call godot_list_toolsets
```

Перед действиями проверить `bridge_connected=true`, правильный `project_path`, `addon_version` и нужную ревизию игры. **Прямых `godot_*` upstream-tools в Local Coder пока нет**: вызовы идут через `run_command` и локальный `mcp_cli.py`. Не придумывать аргументы: сверяться с описанием toolset и схемой инструмента.

Для запуска игры в тестовой копии:
```bash
"$BASE/mcp_cli.py" call godot_enable_toolset '{"category":"runtime"}'
"$BASE/mcp_cli.py" call godot_runtime_play_scene '{}'
"$BASE/mcp_cli.py" call godot_runtime_is_playing '{}'
"$BASE/mcp_cli.py" call godot_runtime_stop_scene '{}'
```
Опция окружения `GODOT_MCP_GODOT_BIN` уже добавлена в `start.sh` для headless-runtime проверок.

## Графический запуск / скриншоты
Проверено на Linux: Xvfb + программный OpenGL, Godot Editor GUI и запущенная игра; изображение получено через `DISPLAY=:87 import -window root .../desktop-shot.png`. Для MCP-скриншота редактора есть `godot_editor_capture_screenshot` после включения toolset `editor`. **Не путать скриншот редактора с кадром игры.**

`godot_runtime_capture_game_screenshot` пока требует дополнительный `mcp_runtime_probe.gd` в autoload и без него возвращает `PRECONDITION_FAILED`. Не добавлять этот autoload в пользовательские игровые файлы без отдельной задачи; для временных тестов использовать копию. Программный рендер может выдавать Vulkan/ALSA/XServer-предупреждения: записывать их и проверять сам полученный PNG, не игнорировать ошибки.

## Ограничения и безопасность
- Для чтения использовать `core` и `inspection`; включать только необходимые toolsets. `scene_edit` и другие мутирующие категории — исключительно для согласованной разработки.
- Не направлять MCP на production или незакоммиченные данные; тестовые сцены и autoload помещать только в изолированные копии.
- Получение кадра доказывает рендер конкретного запуска, но не FPS, боевую логику, сеть и работоспособность на Android.
- Перед тестом и после него проверить `git status`; останавливать временные play-сессии через `godot_runtime_stop_scene`.
