# Introspection targets
# ---------------------

.PHONY: help
help: targets

.PHONY: targets
targets:
	@echo "\033[34mTargets\033[0m"
	@echo "\033[34m---------------------------------------------------------------\033[0m"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

# Build targets
# -------------

.PHONY: dependencies
dependencies: dependencies-mix ## Install dependencies required by the application

.PHONY: dependencies-mix
dependencies-mix:
	mix deps.get --force

# CI targets
# ----------

.PHONY: lint
lint: lint-compile lint-format lint-credo ## Run lint tools on the code

.PHONY: lint-compile
lint-compile:
	mix compile --warnings-as-errors --force

.PHONY: lint-format
lint-format:
	mix format --dry-run --check-formatted

.PHONY: lint-credo
lint-credo:
	mix credo --strict

.PHONY: test
test: ## Run the test suite
	mix test

.PHONY: test-coverage
test-coverage: ## Generate the code coverage report
	mix coveralls

.PHONY: format
format: format-elixir ## Run formatting tools on the code

.PHONY: format-elixir
format-elixir:
	mix format
