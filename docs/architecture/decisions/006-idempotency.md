# ADR-006: Idempotency: Postgres UNIQUE + Redis fast-path
**Статус:** Принято | **Дата:** 2026-11-26
## Контекст
Retry мобильных.
## Решение
Postgres — истина, Redis — кэш, Scheduler чистит.
## Последствия
Надёжно и быстро.
