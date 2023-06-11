.PHONY: build
build:
	docker-compose build -t 

.PHONY: migrate
migrate: build
	docker-compose up migrate