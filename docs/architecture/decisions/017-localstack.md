# ADR-017: LocalStack вместо MinIO
**Статус:** Принято | **Дата:** 2026-11-26
## Контекст
MinIO удалил образы (Docker Hub, quay 401).
## Решение
LocalStack S3 в profile storage, bucket создаётся init-хуком.
## Последствия
Стабильный dev-S3.
