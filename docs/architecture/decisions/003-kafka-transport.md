# ADR-003: Kafka: enqueue/rdkafka + свой TransportFactory
**Статус:** Принято | **Дата:** 2026-11-26
## Контекст
Нужен production Kafka.
## Решение
enqueue как база, свой factory для retry/serialization; fallback ext-rdkafka.
## Последствия
Надёжность + контроль.
