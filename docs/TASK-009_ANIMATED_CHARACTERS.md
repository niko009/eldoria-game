# TASK-009 — Eldoria v0.4.0: анимированные персонажи

## Реализовано

- Вместо временной капсулы теперь 3 персонажа KayKit Adventurers: **Knight, Rogue_Hooded, Mage**. Одна общая GDScript-обёртка `client/animated_actor.gd` и одна сцена Godot для Windows/Android.
- Использованы реальные GLB с 41-костным ригом, AnimationPlayer и 75 клипами. Для прототипа задействованы `Idle`, `Walking_A`, `Running_A`, `Cheer`. Переходы с плавным blend, персонаж поворачивается по направлению движения.
- PC: WASD — ходьба, **Shift + WASD** — ускоренный бег, E — эмоция Cheer, ПКМ — камера. Android: D-pad, кнопка Sprint ON/OFF, Wave вызывает Cheer. На экране остаётся FPS.
- Авторитетный сервер работает с координатами, скоростью, препятствиями как прежде; визуальные GLB на выделенном сервере **не создаются**. По сообщениям позиций клиент воспроизводит движение удалённых игроков, через 300 мс покоя переключает на Idle. При входе игрока назначается один из трёх вариантов по peer ID (до будущего выбора класса/внешности).
- Начальная позиция протокола имеет y=ground+1, а модель смещена на -1 по Y, чтобы ступни были на земле. Коллизии из TASK-008 не изменены.
- Реальный рендер Godot/Mesa/Xvfb, а не концепт-арт: `builds/eldoria-character-preview.png` и сайт `/projects/eldoria/character-preview.png`.

## Лицензия

- Kay Lousberg / KayKit — Character Pack: Adventurers 1.0, лицензия **CC0 1.0 Universal** (файл `client/assets/characters/LICENSE.txt`).
- Исходный репозиторий: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- Официальная страница: https://kaylousberg.itch.io/kaykit-adventurers
- Скачан публичный архив `https://codeload.github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/zip/refs/heads/main`; оставлены 3 GLB и их PNG. Бесплатный набор, без платных ассетов. Attribution не требуется, источник сохранён для аудита.

## Проверки

- Godot импорт GLB: PASS. У Knight, Rogue_Hooded и Mage есть `AnimationPlayer`, 41 кость и проверенные `Idle/Walking_A/Running_A/Cheer`.
- `client/tests/animated_actor_e2e.gd`: начальная поза, движение, бег, эмоция, возврат в Idle, 3 разных модели и headless-режим PASS.
- ENet 2 independent clients + reconnect: PASS. В предыдущем E2E у хоста было физическое препятствие около x≈5; исправлен маршрут теста, а не физика игры.
- Dedicated ENet и WebSocket E2E 2 clients: PASS.
- TASK-008 collision and MultiMesh regression: PASS.
- Export Windows x64 ZIP + Android ARM64 signed APK: PASS при сборке; Android debug сертификат тот же, что в 0.3.1.
- Public WSS endpoint and launcher / auto-update manifest: тестируется при деплое.
- Реальные Windows GPU / Android телефон и OTA UX hardware: **не проверены**, FPS на телефоне не измерен.

## Ограничения

- Пока нет выбора класса или кастомизации; внешний вид автоматически зависит от сетевого ID и может меняться при повторном входе. Это будет исправлено при появлении аккаунтов/профиля.
- Анимация удалённого игрока определяется из полученных координат, состояние отдельно не реплицируется. Для PvP понадобится отдельный authority animation/action protocol.
- Нет прыжка, боевой механики, инвентаря, физики столкновений персонаж-персонаж.
- Это общедоступный pre-alpha сервер без аутентификации и сохранения мира.
