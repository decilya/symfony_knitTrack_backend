# ADR-008: Promotion только для DTO/VO
**Статус:** Принято | **Дата:** 2026-11-26
## Контекст
PHP 8.4 vs прозрачность DI.
## Решение
DTO/Command/Event/VO — promotion+readonly; Services/Entities — явное присвоение.
## Последствия
Меньше boilerplate безопасно.
