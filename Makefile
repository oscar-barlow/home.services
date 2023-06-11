.PHONY: build
build:
	docker-compose build

.PHONY: migrate
migrate: build
	docker-compose up migrate
