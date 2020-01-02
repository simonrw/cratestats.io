all: help

help:
	@echo "Commands: run, devrun, test, frontend"

.PHONY: run
run:
	poetry run uvicorn server:app

.PHONY: devrun
devrun:
	poetry run uvicorn server:app --reload

.PHONY: test
test:
	cargo test

.PHONY: frontend
frontend:
	npm run watch
