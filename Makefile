all: help

help:
	@echo "Commands: run, devrun, test, frontend"

.PHONY: run
run:
	cargo run

.PHONY: devrun
devrun:
	systemfd --no-pid -s http::8080 -- cargo watch -x run

.PHONY: test
test:
	cargo test

.PHONY: frontend
frontend:
	npm run watch
