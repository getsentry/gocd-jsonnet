all: test

.PHONY: fmt
fmt: devenv
	./scripts/fmt.sh

.PHONY: lint
lint: devenv
	./scripts/lint.sh

.PHONY: test
test: fmt lint
	npm run test

.PHONY: devenv
devenv: .done/devenv

# indirect through a .done file so that this only runs when deps have changed
.done/devenv: sbin/install-deps Brewfile jsonnetfile.json package.json
	./sbin/install-deps
	touch .done/devenv  # success
