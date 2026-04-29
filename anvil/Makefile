.PHONY: up down load crash-node stress-cpu logs clean

up:
	docker compose up -d --build

down:
	docker compose down -v

logs:
	docker compose logs -f

# Simulate Blockchain Node Failure (Crash)
crash-node:
	docker compose stop blockchain-node && sleep 120 && docker compose start blockchain-node

# Simulate CPU Pressure (spins up a temporary container to eat CPU)
stress-cpu:
	docker run -d --name cpu-stress --rm alpine sh -c "apk add --no-cache stress-ng && stress-ng --cpu 4 --timeout 60s"

status:
	docker compose ps