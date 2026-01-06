# Use bash for all recipes (GitHub runners + many systems default /bin/sh = dash, no pipefail)
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

MODULE = $(shell go list -m)
VERSION ?= $(shell git describe --tags --always --dirty --match=v* 2> /dev/null || echo "1.0.0")
PACKAGES := $(shell go list ./... | grep -v /vendor/)
LDFLAGS := -ldflags "-X main.Version=${VERSION}"

# DSN is required only for DB-related targets (migrate/testdata), not for build/lint/etc.
APP_DSN ?=

PID_FILE := './.pid'
FSWATCH_FILE := './fswatch.cfg'

.PHONY: require-app-dsn
require-app-dsn:
	@test -n "$(APP_DSN)" || (echo "APP_DSN is required. Set APP_DSN env var."; exit 1)

# IMPORTANT: use '=' (recursive expansion) so APP_DSN is evaluated at runtime
MIGRATE = docker run --rm \
	-v $(shell pwd)/migrations:/migrations \
	--network host \
	migrate/migrate:v4.19.1 \
	-path=/migrations/ -database "$(APP_DSN)"

.PHONY: default
default: help

# generate help info from comments: thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help: ## help information about make commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: test
test: ## run unit tests (fails properly on test failure) and aggregate coverage
	@echo "mode: count" > coverage-all.out
	@rm -f coverage.out
	@for pkg in $(PACKAGES); do \
		echo "==> testing $$pkg"; \
		go test -p=1 -cover -covermode=count -coverprofile=coverage.out "$$pkg"; \
		tail -n +2 coverage.out >> coverage-all.out; \
	done
	@rm -f coverage.out

.PHONY: test-cover
test-cover: test ## run unit tests and print coverage summary (CI-friendly)
	@go tool cover -func=coverage-all.out | tail -n 1

.PHONY: cover-html
cover-html: test ## open HTML coverage report locally
	@go tool cover -html=coverage-all.out

.PHONY: run
run: ## run the API server
	go run ${LDFLAGS} cmd/server/main.go

.PHONY: run-restart
run-restart: ## restart the API server
	@pkill -P "$$(cat $(PID_FILE) 2>/dev/null)" || true
	@printf '%*s\n' "80" '' | tr ' ' -
	@echo "Source file changed. Restarting server..."
	@go run ${LDFLAGS} cmd/server/main.go & echo $$! > $(PID_FILE)
	@printf '%*s\n' "80" '' | tr ' ' -

.PHONY: run-live
run-live: ## run the API server with live reload support (requires fswatch)
	@go run ${LDFLAGS} cmd/server/main.go & echo $$! > $(PID_FILE)
	@fswatch -x -o --event Created --event Updated --event Renamed -r internal pkg cmd config | \
		xargs -n1 -I {} make run-restart

.PHONY: build
build: ## build the API server binary
	CGO_ENABLED=0 go build ${LDFLAGS} -a -o server $(MODULE)/cmd/server

.PHONY: build-docker
build-docker: ## build the API server as a docker image
	docker build -f cmd/server/Dockerfile -t server .

.PHONY: clean
clean: ## remove temporary files
	rm -rf server coverage.out coverage-all.out

.PHONY: version
version: ## display the version of the API server
	@echo $(VERSION)

.PHONY: db-start
db-start: ## start the database server
	@mkdir -p testdata/postgres
	docker run --rm --name postgres -v $(shell pwd)/testdata:/testdata \
		-v $(shell pwd)/testdata/postgres:/var/lib/postgresql/data \
		-e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=go_restful -d -p 5432:5432 postgres

.PHONY: db-stop
db-stop: ## stop the database server
	docker stop postgres

.PHONY: testdata
testdata: require-app-dsn ## populate the database with test data
	@$(MAKE) migrate-reset
	@echo "Populating test data..."
	@docker exec -it postgres psql "$(APP_DSN)" -f /testdata/testdata.sql

.PHONY: lint
lint: ## run golint on all Go packages
	@golint $(PACKAGES)

.PHONY: fmt
fmt: ## run "go fmt" on all Go packages
	@go fmt $(PACKAGES)

.PHONY: migrate
migrate: require-app-dsn ## run all new database migrations
	@echo "Running all new database migrations..."
	@$(MIGRATE) up

.PHONY: migrate-down
migrate-down: require-app-dsn ## revert database to the last migration step
	@echo "Reverting database to the last migration step..."
	@$(MIGRATE) down 1

.PHONY: migrate-new
migrate-new: require-app-dsn ## create a new database migration
	@read -p "Enter the name of the new migration: " name; \
	$(MIGRATE) create -ext sql -dir /migrations/ $${name// /_}

.PHONY: migrate-reset
migrate-reset: require-app-dsn ## reset database and re-run all migrations
	@echo "Resetting database..."
	@$(MIGRATE) drop
	@echo "Running all database migrations..."
	@$(MIGRATE) up
