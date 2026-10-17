.DEFAULT_GOAL := test

fmt:
	./scripts/fmt.sh
.PHONY: fmt

lint:
	./scripts/lint.sh
	npm run lint
.PHONY: lint

test: fmt lint
	npm run test
.PHONY: test
