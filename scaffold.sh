#!/usr/bin/env bash
set -euo pipefail

mkdir -p docker/php docker/nginx/certs docker/localstack docker/observability/grafana/datasources \
  docs/architecture/decisions docs/api .github/workflows scripts \
  src/Auth/Domain/{Entity,ValueObject,Event,Repository,Service} src/Auth/Application/{Command,CommandHandler,DTO} \
  src/Auth/Infrastructure/{Persistence,Security,Outbox} src/Auth/Presentation/Http \
  src/Sync/Domain/{Entity,ValueObject,Event,Repository,Port,Service} src/Sync/Application/{Command,CommandHandler,Query,QueryHandler,DTO} \
  src/Sync/Infrastructure/{Persistence,Storage,Idempotency,ConflictResolution,Outbox} src/Sync/Presentation/Http \
  src/Projects/Domain/{Entity,ValueObject,Event,Repository} src/Projects/Application/{Command,CommandHandler,Query,QueryHandler,DTO} \
  src/Projects/Infrastructure/Persistence src/Projects/Presentation/Http \
  src/Notification/Domain/{Entity,Event,Repository} src/Notification/Application/CommandHandler \
  src/Notification/Infrastructure/{Email,Kafka,Persistence} \
  src/Shared/Domain/{Entity,Event,ValueObject,Exception} \
  src/Shared/Infrastructure/{Doctrine/Types,Doctrine/Listener,Serializer/Normalizer,Security,Kafka,Scheduler,OpenApi} \
  tests/Auth/{Unit,Integration,E2E} tests/Sync/{Unit,Integration,E2E} tests/Notification/{Unit,Integration} \
  tests/Shared/{Unit,Integration} tests/Architecture
touch docker/nginx/certs/.gitkeep docker/observability/grafana/dashboards/.gitkeep 2>/dev/null || mkdir -p docker/observability/grafana/dashboards && touch docker/observability/grafana/dashboards/.gitkeep

cat << 'EOF' > Makefile
.PHONY: up up-storage demo down shell console migrate test stan cs-check cs-fix rector infect deptrac openapi logs grafana mailpit

check-fs:
	@if echo "$$(pwd)" | grep -q "^/mnt/"; then \
		echo "ERROR: run from WSL2 filesystem (~/projects/), not /mnt/c/"; exit 1; \
	fi

up: check-fs
	docker compose up -d --wait

up-storage: check-fs
	docker compose --profile storage up -d --wait

demo: check-fs
	docker compose -f docker-compose.yml -f docker-compose.demo.yml --profile storage up -d --wait

down:
	docker compose -f docker-compose.yml -f docker-compose.demo.yml -f docker-compose.storage.yml --profile storage down -v

shell: check-fs
	docker compose exec php sh

console:
	docker compose exec php bin/console $(cmd)

migrate:
	docker compose exec php bin/console doctrine:migrations:migrate --no-interaction

test: check-fs
	docker compose exec php vendor/bin/phpunit

stan: check-fs
	docker compose exec php vendor/bin/phpstan analyse --level=max

cs-check: check-fs
	docker compose exec php vendor/bin/php-cs-fixer fix --dry-run --diff

cs-fix: check-fs
	docker compose exec php vendor/bin/php-cs-fixer fix

rector: check-fs
	docker compose exec php vendor/bin/rector process --dry-run

infect: check-fs
	docker compose exec php vendor/bin/infection --min-msi=85

deptrac:
	docker compose exec php vendor/bin/deptrac analyse

openapi:
	docker compose exec php bin/console app:openapi:generate

logs:
	docker compose logs -f

grafana:
	@echo "http://localhost:3000 (admin/knittrack)"

mailpit:
	@echo "http://localhost:8025"
EOF

cat << 'EOF' > docker-compose.yml
services:
  nginx:
    image: nginx:1.27-alpine
    ports: ["8080:80"]
    volumes:
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./public:/var/www/html/public:ro
    depends_on:
      php: { condition: service_started }
    networks: [knittrack]

  php:
    build:
      context: ./docker/php
      args: { PHP_VERSION: "8.4" }
    user: "1000:1000"
    volumes:
      - ./:/var/www/html:cached
      - composer_cache:/tmp/composer-cache
    environment:
      APP_ENV: dev
      APP_SECRET: ${APP_SECRET:-change_me_in_prod}
      COMPOSER_HOME: /tmp/composer-home
      COMPOSER_CACHE_DIR: /tmp/composer-cache
      DATABASE_URL: postgresql://knittrack:knittrack@postgres:5432/knittrack?serverVersion=16
      MESSENGER_TRANSPORT_DSN: enqueue://kafka/knittrack.events
      MESSENGER_OUTBOX_DSN: doctrine://default
      REDIS_URL: redis://redis:6379
      MAILER_DSN: smtp://mailpit:1025
      S3_ENDPOINT: http://localstack:4566
      S3_REGION: us-east-1
      S3_ACCESS_KEY_ID: test
      S3_SECRET_ACCESS_KEY: test
      S3_BUCKET: knittrack-backups
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }
      kafka: { condition: service_healthy }
    networks: [knittrack]

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: knittrack
      POSTGRES_USER: knittrack
      POSTGRES_PASSWORD: knittrack
    ports: ["5432:5432"]
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U knittrack --timeout=5"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s
    networks: [knittrack]

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    ports: ["6379:6379"]
    volumes: [redisdata:/data]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks: [knittrack]

  kafka:
    image: apache/kafka:3.9.0
    ports: ["9092:9092", "9093:9093"]
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9094
      KAFKA_LISTENERS: INTERNAL://0.0.0.0:9092,EXTERNAL://0.0.0.0:9093,CONTROLLER://0.0.0.0:9094
      KAFKA_ADVERTISED_LISTENERS: INTERNAL://kafka:9092,EXTERNAL://localhost:9093
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT,CONTROLLER:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: INTERNAL
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_HEAP_OPTS: "-Xmx512m -Xms256m"
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
    volumes: [kafkadata:/tmp/kraft-combined-logs]
    healthcheck:
      test: ["CMD-SHELL", "nc -z kafka 9092 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    networks: [knittrack]

  mailpit:
    image: axllent/mailpit:v1.22
    ports: ["1025:1025", "8025:8025"]
    networks: [knittrack]

volumes:
  pgdata:
  redisdata:
  kafkadata:
  composer_cache:

networks:
  knittrack:
    driver: bridge
EOF

cat << 'EOF' > docker-compose.storage.yml
services:
  localstack:
    image: localstack/localstack:latest
    profiles: ["storage"]
    ports: ["4566:4566"]
    environment:
      SERVICES: s3
      DEFAULT_REGION: us-east-1
    volumes:
      - ./docker/localstack/init.sh:/etc/localstack/init/ready.d/init.sh:ro
      - localstackdata:/var/lib/localstack
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4566/_localstack/health"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s
    networks: [knittrack]

volumes:
  localstackdata:
EOF

cat << 'EOF' > docker/localstack/init.sh
#!/bin/bash
awslocal s3 mb s3://knittrack-backups || true
EOF
chmod +x docker/localstack/init.sh

cat << 'EOF' > docker-compose.demo.yml
services:
  tempo:
    image: grafana/tempo:latest
    command: ["-config.file=/etc/tempo.yaml"]
    volumes:
      - ./docker/observability/tempo.yaml:/etc/tempo.yaml:ro
      - tempodata:/tmp/tempo
    ports: ["3200:3200", "4318:4318"]
    networks: [knittrack]

  loki:
    image: grafana/loki:latest
    command: ["-config.file=/etc/loki/local-config.yaml"]
    volumes:
      - ./docker/observability/loki-config.yaml:/etc/loki/local-config.yaml:ro
      - lokidata:/loki
    ports: ["3100:3100"]
    networks: [knittrack]

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./docker/observability/prometheus.yaml:/etc/prometheus/prometheus.yml:ro
      - prometheusdata:/prometheus
    ports: ["9090:9090"]
    networks: [knittrack]

  kafka-exporter:
    image: danielqsj/kafka-exporter:latest
    command: ["--kafka.server=kafka:9092"]
    ports: ["9308:9308"]
    depends_on:
      kafka: { condition: service_healthy }
    networks: [knittrack]

  grafana:
    image: grafana/grafana:latest
    ports: ["3000:3000"]
    environment:
      GF_SECURITY_ADMIN_PASSWORD: knittrack
    volumes:
      - grafanadata:/var/lib/grafana
      - ./docker/observability/grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./docker/observability/grafana/datasources:/etc/grafana/provisioning/datasources:ro
    depends_on: [tempo, loki, prometheus]
    networks: [knittrack]

volumes:
  tempodata:
  lokidata:
  prometheusdata:
  grafanadata:
EOF

cat << 'EOF' > docker/php/Dockerfile
ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-alpine

RUN apk add --no-cache \
    git unzip libzip-dev icu-dev postgresql-dev \
    linux-headers autoconf g++ make rdkafka-dev \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    netcat-openbsd su-exec

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_pgsql intl zip opcache sockets gd bcmath \
    && pecl install rdkafka-6.0.0 \
    && docker-php-ext-enable rdkafka

COPY php.ini.dev /usr/local/etc/php/conf.d/opcache.ini.dev
COPY php.ini.prod /usr/local/etc/php/conf.d/opcache.ini.prod
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN pecl install xdebug && docker-php-ext-enable xdebug

WORKDIR /var/www/html
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
USER www-data
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
EOF

cat << 'EOF' > docker/php/docker-entrypoint.sh
#!/bin/sh
set -e
if [ "$APP_ENV" = "prod" ]; then
    cp /usr/local/etc/php/conf.d/opcache.ini.prod /usr/local/etc/php/conf.d/opcache.ini
else
    cp /usr/local/etc/php/conf.d/opcache.ini.dev /usr/local/etc/php/conf.d/opcache.ini
fi
if [ "$(id -u)" = "0" ]; then
    mkdir -p /var/www/html/var
    chown -R www-data:www-data /var/www/html/var
    exec su-exec www-data "$@"
fi
exec "$@"
EOF
chmod +x docker/php/docker-entrypoint.sh

cat << 'EOF' > docker/php/php.ini.dev
[PHP]
memory_limit = 512M
max_execution_time = 60
upload_max_filesize = 100M
post_max_size = 100M
date.timezone = UTC

[opcache]
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=1
opcache.revalidate_freq=2
EOF

cat << 'EOF' > docker/php/php.ini.prod
[PHP]
memory_limit = 512M
max_execution_time = 60
upload_max_filesize = 100M
post_max_size = 100M
date.timezone = UTC

[opcache]
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=1
opcache.revalidate_freq=0
EOF

cat << 'EOF' > docker/php/www.conf
[www]
user = www-data
group = www-data
listen = 127.0.0.1:9000
pm = dynamic
pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 8
pm.max_requests = 500
EOF

cat << 'EOF' > docker/nginx/default.conf
server {
    listen 80;
    server_name localhost;
    root /var/www/html/public;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass php:9000;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
        internal;
    }

    location ~ \.php$ {
        return 404;
    }
}
EOF

cat << 'EOF' > docker/observability/tempo.yaml
server:
  http_listen_port: 3200
distributor:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: "0.0.0.0:4318"
storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/blocks
EOF

cat << 'EOF' > docker/observability/loki-config.yaml
auth_enabled: false
server:
  http_listen_port: 3100
schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h
storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks
EOF

cat << 'EOF' > docker/observability/prometheus.yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'kafka'
    static_configs:
      - targets: ['kafka-exporter:9308']
EOF

cat << 'EOF' > docker/observability/grafana/datasources/datasources.yaml
apiVersion: 1
datasources:
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    isDefault: true
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
EOF

cat << 'EOF' > deptrac.yaml
deptrac:
  paths:
    - ./src
  layers:
    - name: Domain
      collectors: [{ type: className, regex: ^App\\(Auth|Sync|Projects|Notification)\\Domain\\.* }]
    - name: Application
      collectors: [{ type: className, regex: ^App\\(Auth|Sync|Projects|Notification)\\Application\\.* }]
    - name: Infrastructure
      collectors: [{ type: className, regex: ^App\\(Auth|Sync|Projects|Notification|Shared)\\Infrastructure\\.* }]
    - name: Presentation
      collectors: [{ type: className, regex: ^App\\(Auth|Sync|Projects|Notification)\\Presentation\\.* }]
    - name: Shared
      collectors: [{ type: className, regex: ^App\\Shared\\Domain\\.* }]
  ruleset:
    Domain: [Shared]
    Application: [Domain, Shared]
    Infrastructure: [Domain, Application, Shared]
    Presentation: [Application, Shared]
    Shared: ~
EOF

cat << 'EOF' > phpstan.neon
includes:
    - vendor/phpstan/phpstan-symfony/extension.neon
    - vendor/phpstan/phpstan-doctrine/extension.neon
parameters:
    level: max
    paths: [src]
    excludePaths: ['*/Tests/*']
EOF

cat << 'EOF' > infection.json5
{
    "source": { "directories": ["src"] },
    "logs": { "text": "infection.log" },
    "minMsi": 85,
    "minCoveredMsi": 90,
    "mutators": { "@default": true },
    "testFramework": "phpunit"
}
EOF

cat << 'EOF' > rector.php
<?php
declare(strict_types=1);
use Rector\Config\RectorConfig;
use Rector\Set\ValueObject\SetList;
use Rector\Symfony\Set\SymfonySetList;
return RectorConfig::configure()
    ->withPaths([__DIR__ . '/src'])
    ->withSets([SetList::PHP_84, SymfonySetList::SYMFONY_74]);
EOF

cat << 'EOF' > .php-cs-fixer.dist.php
<?php
declare(strict_types=1);
$finder = (new PhpCsFixer\Finder())->in(__DIR__ . '/src')->in(__DIR__ . '/tests');
return (new PhpCsFixer\Config())
    ->setRules(['@Symfony' => true, '@PHP84Migration' => true, 'declare_strict_types' => true])
    ->setFinder($finder);
EOF

cat << 'EOF' > .github/workflows/ci.yml
name: CI
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
jobs:
  static-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with: { php-version: '8.4', extensions: rdkafka, pdo_pgsql, intl, coverage: none }
      - run: composer install --no-interaction --prefer-dist
      - run: vendor/bin/phpstan analyse --level=max
      - run: vendor/bin/php-cs-fixer fix --dry-run --diff
      - run: vendor/bin/deptrac analyse
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with: { php-version: '8.4', extensions: rdkafka, pdo_pgsql, intl, coverage: pcov }
      - run: composer install --no-interaction --prefer-dist
      - run: vendor/bin/phpunit --coverage-clover=coverage.xml
      - run: vendor/bin/infection --min-msi=85
  openapi:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: oasdiff/oasdiff-action@v1
        with: { base: docs/api/openapi.baseline.yaml, revision: docs/api/openapi.yaml, fail-on: ERR }
EOF

adr() { cat << EOF > "docs/architecture/decisions/$1-$2.md"
# ADR-$1: $3
**Статус:** Принято | **Дата:** 2026-11-26
## Контекст
$4
## Решение
$5
## Последствия
$6
EOF
}
adr 001 modular-monolith "Modular Monolith" "Соло-разработчик, нет трафика." "Модули Auth/Sync/Projects/Notification/Shared, события через Kafka." "Вынос в микросервис — один PR при >10k RPS."
adr 002 no-api-platform "Без API Platform" "Портфолио = глубина Symfony." "Ручные контроллеры + MapRequestPayload + serializer." "Прозрачность вместо магии."
adr 003 kafka-transport "Kafka: enqueue/rdkafka + свой TransportFactory" "Нужен production Kafka." "enqueue как база, свой factory для retry/serialization; fallback ext-rdkafka." "Надёжность + контроль."
adr 004 outbox "Transactional Outbox + DLQ" "Dual-write теряет события." "Outbox-таблица в транзакции + relay; DLQ после 5 попыток." "Гарантированная доставка."
adr 005 presigned "Presigned URLs" "PHP-FPM не для streaming." "POST /backups -> presigned PUT -> confirm; download presigned GET 5 мин." "Масштабируется."
adr 006 idempotency "Idempotency: Postgres UNIQUE + Redis fast-path" "Retry мобильных." "Postgres — истина, Redis — кэш, Scheduler чистит." "Надёжно и быстро."
adr 007 normalizer "ObjectNormalizer + groups" "PropertyNormalizer ломает readonly DTO." "ObjectNormalizer с groups." "Контроль JSON."
adr 008 promotion "Promotion только для DTO/VO" "PHP 8.4 vs прозрачность DI." "DTO/Command/Event/VO — promotion+readonly; Services/Entities — явное присвоение." "Меньше boilerplate безопасно."
adr 009 no-result "Без Result<T> в API" "Два канала ошибок." "Exceptions -> 4xx/5xx; успех — DTO." "Чище контракт."
adr 010 optimistic "Optimistic locking @Version" "Без pessimistic locking." "@Version на агрегатах." "Нет deadlocks."
adr 011 jwt "Native JWT + rotation" "lexik тяжёл." "AccessTokenHandler + lcobucci/jwt; access 15 мин, refresh 30 дней, rotation + reuse detection." "Production-ready auth."
adr 012 versioning "URI /api/v1/" "Контракт для Android." "URI versioning." "Breaking = bump."
adr 013 cloudevents "CloudEvents + oasdiff" "Schema evolution." "CloudEvents envelope; oasdiff в CI." "Защита контракта."
adr 014 testcontainers "Testcontainers" "Самодостаточные тесты." "testcontainers-php, backgroundScope, tearDown." "Reliable integration."
adr 015 cs-fixer "PHP-CS-Fixer" "Pint = Laravel." "@Symfony + @PHP84Migration, CI dry-run." "Стандарт."
adr 016 rate-limit "Rate limiting" "Abuse." "auth 5/min IP, register 3/hour IP, sync 60-120/min user, global 1000/min." "Защита без блокировки легитимных."
adr 017 localstack "LocalStack вместо MinIO" "MinIO удалил образы (Docker Hub, quay 401)." "LocalStack S3 в profile storage, bucket создаётся init-хуком." "Стабильный dev-S3."

cat << 'EOF' > docs/api/openapi.baseline.yaml
openapi: 3.1.0
info: { title: KnitTrack API, version: 1.0.0 }
paths: {}
EOF
cp docs/api/openapi.baseline.yaml docs/api/openapi.yaml

cat << 'EOF' > README.md
# KnitTrack Backend v2.0
Symfony 7.4 LTS modular monolith для KnitTrack Android.
Стек: PHP 8.4, PostgreSQL 16, Kafka 3.9 (KRaft), Redis 7, LocalStack S3 (profile storage), Mailpit, Grafana (demo).
Старт: make up | make shell | make test | make stan
ADR: docs/architecture/decisions (001-017).
EOF

cat << 'EOF' > .env
APP_ENV=dev
APP_SECRET=change_me_in_prod_32_chars_min
DATABASE_URL=postgresql://knittrack:knittrack@postgres:5432/knittrack?serverVersion=16
MESSENGER_TRANSPORT_DSN=enqueue://kafka/knittrack.events
REDIS_URL=redis://redis:6379
MAILER_DSN=smtp://mailpit:1025
S3_ENDPOINT=http://localstack:4566
S3_REGION=us-east-1
S3_ACCESS_KEY_ID=test
S3_SECRET_ACCESS_KEY=test
S3_BUCKET=knittrack-backups
EOF

for e in '/.php-cs-fixer.cache' '/.phpunit.result.cache' '/infection.log' '/coverage.xml'; do
  grep -qxF "$e" .gitignore 2>/dev/null || echo "$e" >> .gitignore
done

echo "OK. Дальше:"
echo "  make up"
echo "  make shell"
echo "  composer install"
echo "  composer require doctrine/orm doctrine/doctrine-bundle doctrine/doctrine-migrations-bundle symfony/serializer symfony/validator symfony/security-bundle symfony/messenger symfony/doctrine-messenger symfony/redis-messenger symfony/uid symfony/clock symfony/rate-limiter symfony/scheduler symfony/mailer lcobucci/jwt aws/aws-sdk-php zircote/swagger-php enqueue/rdkafka enqueue/enqueue-bundle"
echo "  composer require --dev phpunit/phpunit:^11.5 phpstan/phpstan phpstan/phpstan-symfony phpstan/phpstan-doctrine friendsofphp/php-cs-fixer rector/rector qossmic/deptrac infection/infection:^0.29 testcontainers/testcontainers-php symfony/browser-kit symfony/http-client"
echo "  exit && bin/console -V (через make console)"
echo "  S3: make up-storage (LocalStack, бакет создастся сам)"