.DEFAULT_GOAL := all

all: fmt lint test
.PHONY: all

fmt:
	./scripts/fmt.sh
.PHONY: fmt

lint:
	./scripts/lint.sh
.PHONY: lint

test:
	npm run test
.PHONY: test
