# ADR-005: Presigned URLs
**Статус:** Принято | **Дата:** 2026-11-26
## Контекст
PHP-FPM не для streaming.
## Решение
POST /backups -> presigned PUT -> confirm; download presigned GET 5 мин.
## Последствия
Масштабируется.
