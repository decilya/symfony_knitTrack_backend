# KnitTrack Backend v2.0

Production-ready Symfony 7.4 LTS modular monolith для Android-приложения KnitTrack.

## Стек
- **Runtime:** PHP 8.4 + Symfony 7.4 LTS
- **DB:** PostgreSQL 16 + Doctrine ORM 3
- **Queue:** Kafka 3.9 (Redpanda, KRaft) + enqueue/rdkafka + custom TransportFactory
- **Cache/Keys:** Redis 7 (idempotency fast-path + rate limiter + failure transport)
- **Storage:** LocalStack (S3-compatible, presigned PUT/GET, приватный bucket, profile: `storage`)
- **Mail:** Mailpit (dev SMTP catch-all)
- **Observability:** OpenTelemetry + Grafana Tempo/Loki/Prometheus (demo profile)

## Принципы
- **SOLID** на всех уровнях, без исключений.
- **DDD**: Aggregates + Value Objects + Domain Events через Transactional Outbox.
- **TDD**: Unit ≥90%, Integration ≥80%, E2E 10-15 сценариев, Mutation ≥85%.
- **Contract-first (OpenAPI ≠ Symfony)**: OpenAPI 3.1 spec — это *только контракт* для генерации Android-клиента. Реализация — чистый Symfony 7.4 (без API Platform), использующий `#[MapRequestPayload]`, `Validator` и `ObjectNormalizer` для строгого соответствия спецификации.

## Быстрый старт
```bash
mkdir -p ~/projects/knittrack-backend && cd ~/projects/knittrack-backend
# (Предполагается, что файлы docker-compose, Makefile и scaffold.sh уже созданы)
make up
make shell

# Внутри контейнера:
composer install
bin/console -V
```

## Bounded Contexts
- `Auth` — JWT, refresh tokens (rotation + reuse detection), voters.
- `Sync` — backups, idempotency, conflict resolution (Strategy pattern).
- `Projects` — CRUD, statistics.
  -`()
11. Sync Infrastructure: LocalStack presigned URLs, Postgres Idempotency, Redis fast-path
12. Sync Application + Presentation + E2E
13. Observability: OpenTelemetry instrumentation + Grafana dashboards
14. Kafka consumer (Notification) + Outbox Relay Worker
15. Final polish: Infection MSI, Deptrac, OpenAPI lint, README финализация

## Критерии готовности
1. `make up` поднимает весь стек на WSL2 (кроме localstack, он в profile `storage`).
2. `make test` — 100% pass.
3. `make stan && make cs-check && make rector` — 0 ошибок.
4. `make deptrac` — 0 нарушений границ слоев.
5. `make infect` — MSI ≥ 85% Domain, ≥ 80% App, ≥ 60% Infra.
6. 17 ADR закоммичены в `docs/architecture/decisions/`.
7. README содержит схему архитектуры и скриншоты Grafana.
8. CI зелёный (PHP 8.4 only).
