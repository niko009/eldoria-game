# Eldoria — сверка 45 пунктов очередей и выпуск v0.5.28
Дата: 2026-11-08. Основа: production v0.5.27, commit `f4e632fb`; новые изменения из PR #52. Релизный статус фиксировать **только после фактического деплоя**.

## Метод
Сверены: `docs/ELDORIA_AUTOMATION_QUEUE.json`, спецификации `TASK-093_124_COOPERATIVE_TASKS.md`, история `RELEASE_0527_TASK_AUDIT.md`, `ELDORIA_LEGACY_BACKLOG_RECONCILIATION.md`, исходники `client/main.gd`, `client/ui/live_ui.gd`, JSON + PostgreSQL persistence, скрипты и тесты. `TESTED` означает только явно описанные тесты; не означает Android hardware или все критерии задачи. `IN_PROGRESS` означает частично реализовано, **не** работа агента в фоне.

## Проверка автономной очереди (31)
| ID | Статус | Подтверждённая реализация и оставшийся риск |
|---|---|---|
| A-01 TASK-089 | TESTED (частично) | Числовой HP и фокус existing mobs, targeted Godot test `task089_hp_labels_e2e.gd` в предыдущей интеграции; **Android и WSS двух игроков для HP не подтверждены**. |
| A-02 TASK-087 GP01–04 | IN_PROGRESS | Тест расхода стрел, joystick+attack pause, смена оружия: код/частичные тесты есть; реальное исправление жалобы Android «5→0» и full 2-device acceptance не доказаны. |
| A-03 TASK-087 GP06–08 | IN_PROGRESS | Посох+щит, расходники в коде; новая tree regrowth логика JSON+WSS протестирована. Для завершения нужна проверка PostgreSQL и телефона. |
| A-04 TASK-090 | IN_PROGRESS | Каталог 85 исходных ассетов/иконок; отсутствует полный визуальный before/after и утверждённые замены. |
| A-05 TASK-087 UI | IN_PROGRESS | Анализ HUD/регрессии, но реальный Android scroll/safe-area и полный UX не принят. |
| A-06 TASK-088 QUEST | TODO | В `main.gd` нет законченного server quest engine и идемпотентных наград/сохранения. |
| A-07 TASK-088 MAGIC | TODO | Persistence хранит поле `magic`/magic_xp, но независимая серверная прокачка заклинаний не подтверждена. |
| A-08 TASK-091 | TODO | Не подготовлено 6 реально проверенных rigged/animated mob-кандидатов с лицензиями и preview. |
| A-09 QA-PERFORMANCE | TODO | Отдельный полный performance/WSS/Android audit не выполнялся; отдельные тесты остальных задач не заменяют его. |
| A-10 TASK-093 | TODO | Нет complete 5–10 min onboarding с durable unique reward. |
| A-11 TASK-094 | TODO | Нет авторитетного invite/party state, синхронного team quest HUD, join/leave и закрытых персональных наград. |
| A-12 TASK-095 | IN_PROGRESS | Только `coop_revive_policy.gd` и policy-test; нет серверного downed state, hold-to-revive UI/network. |
| A-13 TASK-096 | TODO | Имеющиеся taunt/mage-heal — не реализованная целиком новая синергия 3 классов. |
| A-14 TASK-097 | TODO | Нет совместного двухрычажного взаимодействия в руинах с solo path и серверной проверкой. |
| A-15 TASK-098 | TODO | Нет работающей главы «Следы в лесу» на 25–40 минут с фазами/сохранением/наградами. |
| A-16 TASK-099 | TODO | Alpha wolf существует, но 2 паттерна и этапы с telegraph/retry не доказаны. |
| A-17 TASK-100 | TODO | Existing loot/XP не равны кооперативному итоговому экрану и идемпотентной персональной награде. |
| A-18 TASK-102 | TODO | Нет подтверждённого solo/duo balance E2E и результата TTK/deaths. |
| A-19 TASK-104 | TODO | 60-минутный реальный проход с ребёнком и двухклиентский сквозной квест-тест не выполнялись. |
| A-20 TASK-101 | TODO | Existing campfire/tent не обеспечивают два утверждённых функциональных upgrade + права хранения. |
| A-21 TASK-103 | TODO | Existing craft/combat — не подтверждение законченной цепочки собрать→craft→применить для дуо. |
| A-22 TASK-105 | TODO | Нет трёх сценариев повторяемых экспедиций с независимой reward-идемпотентностью. |
| A-23 TASK-106 | TODO | Нет серверных персональных одноразовых тайников и подсказок. |
| A-24 TASK-107 | TODO | Rogue dash существует; party-mark/trap с серверным cooldown ещё отсутствуют. |
| A-25 TASK-108 | TODO | Existing night raid — не две отдельные проверенные оборонные цели. |
| A-26 TASK-109 | TODO | Нет NPC escort с сохранением и восстановлением после разрыва. |
| A-27 TASK-110 | TODO | Нет party-only ping navigation с rate-limit и UI. |
| A-28 TASK-111 | TODO | Нет двух уровней улучшения вооружения с серверным списанием/сохранением. |
| A-29 TASK-112 | TODO | Нет class talent выбора, отдельный magic XP ещё не доведён. |
| A-30 TASK-113 | TODO | Нет сохранённых server-backed достижений solo/coop. |
| A-31 TASK-114 | TODO | Нет secure party help/gather marker и безопасной навигации. |

## Очередь B (4, все APPROVAL_REQUIRED)
B-01: выбор 4 моделей мобов и конкретных анимаций; B-02: замена всего арт-стиля/иконок; B-03: конкретный UI-редизайн и жесты; B-04: большие продуктовые/lore/PvP решения. **Команда «выпусти релиз» не означает утверждения неподготовленных вариантов.**

## Отложенные P2 (10, все DEFERRED)
TASK-115, 116, 117, 118, 119, 120, 121, 122, 123, 124: отдельные будущие блоки. Ни один не объявлен готовым, в production не включаются.

## Вывод
Только A-01 имеет подтверждённые targeted-тесты, но ещё не закрывает hardware/network acceptance. Частично реализованы A-02/03/04/05/12. Остальные 25 автономных пунктов — TODO; 4 B — APPROVAL_REQUIRED и 10 P2 — DEFERRED. **0 пунктов удовлетворяют всем критериям DONE.** Изменение меток не дорисовывает отсутствующие функции. Новая проверка A-03 в PR #52 должна добавить фактические PG test logs или оставить NOT_VERIFIED.

## Границы релиза
В production допустимы только интегрированные проверенные изменения. TASK-087.06 требует **после подтверждённого backup** добавить PG колонку `regrow_at_unix` (SQL 012), обновить отдельно .NET API и только затем Godot server/Android/Windows на идентичном исходнике. Обычный `eldoria-release` этого не делает. Если эти действия нельзя безопасно выполнить, релизный gate считается BLOCKED, публиковать несовместимый клиент/сервер нельзя. Физический Android и субъективный интерес ребёнка остаются NOT_VERIFIED.
