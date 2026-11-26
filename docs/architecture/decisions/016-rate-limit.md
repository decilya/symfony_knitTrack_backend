# ADR-016: Rate limiting
**Статус:** Принято | **Дата:** 2026-11-26
## Контекст
Abuse.
## Решение
auth 5/min IP, register 3/hour IP, sync 60-120/min user, global 1000/min.
## Последствия
Защита без блокировки легитимных.
