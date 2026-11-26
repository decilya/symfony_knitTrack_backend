# KnitTrack Backend v2.0

Production-ready Symfony 7.4 LTS modular monolith для Android-приложения KnitTrack.

## Стек
- PHP 8.4 + Symfony 7.4 LTS
- PostgreSQL 16 + Doctrine ORM 3
- Kafka 3.9 (KRaft) + enqueue/rdkafka + custom TransportFactory
- Redis 7 (idempotency fast-path + rate limiter + failure transport)
- MinIO (S3-compatible, presigned PUT/GET, приватный bucket)
- Mailpit (dev SMTP)
- OpenTelemetry + Grafana Tempo/Loki/Prometheus (demo profile)

## Принципы
- **SOLID** на всех уровнях, без исключений
- **DDD**: Aggregates + Value Objects + Domain Events через Outbox
- **TDD**: Unit ≥90%, Integration ≥80%, E2E 10-15 сценариев, Mutation ≥85%
- **Contract-first**: OpenAPI 3.1 spec как единственный контракт для Android

## Быстрый старт
```bash
mkdir -p ~/projects/knittrack-backend && cd ~/projects/knittrack-backend
bash init-backend.sh
make up
make shell
# внутри контейнера:
composer create-project symfony/skeleton:"7.4.*" /tmp/skel --no-install --no-scripts
cp -rn /tmp/skel/. . && rm -rf /tmp/skel
composer install
bin/console -V
```

## Bounded Contexts
- `Auth` — JWT, refresh tokens, voters
- `Sync` — backups, idempotency, conflict resolution
- `Projects` — CRUD, statistics
- `Notification` — async email via Kafka
- `Shared` — BaseEntity, Uuid, DomainEvent, Result

## 15 шагов реализации
1. WSL2 prep + scaffold Symfony 7.4
2. ADR-001..ADR-017
3. Docker-инфраструктура (этот init-backend.sh)
4. PHPStan + Deptrac + PHP-CS-Fixer + Rector + Infection + CI
5. Shared Domain: BaseEntity, Uuid, Timestamp, DomainEvent, exceptions
6. Shared Infrastructure: DBAL types, listeners, CloudEvents, migration v1
7. Auth Domain + Application
8. Auth Infrastructure: JwtAccessTokenHandler, RefreshTokenRotation, Voter
9. Auth Presentation + E2E
10. Sync Domain: Backup aggregate, ConflictResolutionStrategy
11. Sync Infrastructure: MinIO presigned, Idempotency, Redis fast-path
12. Sync Application + Presentation + E2E
13. Observability: OpenTelemetry + Grafana
14. Kafka consumer (Notification) + Outbox Relay Worker
15. Final polish: Infection MSI, Deptrac, OpenAPI lint

## Критерии готовности
1. `make up` поднимает весь стек на WSL2
2. `make test` — 100% pass
3. `make stan && make cs-check && make rector` — 0 ошибок
4. `make deptrac` — 0 нарушений границ
5. `make infect` — MSI ≥ 85% Domain, ≥ 80% App, ≥ 60% Infra
6. 17 ADR закоммичены
7. README со схемой архитектуры + скриншотами Grafana
8. CI зелёный (PHP 8.4)
