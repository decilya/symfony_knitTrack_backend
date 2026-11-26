.PHONY: up down shell fix-permissions logs

check-network:
	@if echo "$$(pwd)" | grep -q "^/mnt/"; then echo "ERROR: WSL2 only"; exit 1; fi

up: check-network
	docker compose up -d --wait

down:
	docker compose down -v

shell: check-network
	docker compose exec php sh

fix-permissions:
	sudo chown -R $$(id -u):$$(id -g) .

logs:
	docker compose logs -f
