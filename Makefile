ifneq (,$(wildcard ./.env))
    include .env
    export
endif

.PHONY: all clean build slither lint fmt test coverage-summary coverage-check pre-commit docs

help: ## Print all targets and descriptions
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[.a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } END { printf "\n" }' $(MAKEFILE_LIST)

all: ## Clean, build, lint, slither and test
	make clean && \
	make build && \
	make lint && \
	make slither && \
	make test

clean: ## Clean the project
	forge clean && rm -rf cache out

build: ## Build the project forcefully
	forge build --force

slither: ## Run slither
	slither . --include-paths "(src)" --fail-low --config-file slither.config.json

lint: ## Run lint
	forge fmt --check && \
  	solhint -c .solhint.json --max-warnings 0 "src/**/*.sol"  && \
  	solhint -c script/.solhint.json --max-warnings 0 "script/**/*.sol" && \
  	solhint -c test/.solhint.json --max-warnings 0 "test/**/*.t.sol"

fmt:
	forge fmt && \
  	solhint -c .solhint.json --max-warnings 0 "src/**/*.sol"  && \
  	solhint -c script/.solhint.json --max-warnings 0 "script/**/*.sol" && \
  	solhint -c test/.solhint.json --max-warnings 0 "test/**/*.t.sol"

test: ## Run tests
	forge test --force --isolate -vvv --show-progress

coverage-summary: ## Run tests and generate coverage summary
	forge coverage --no-match-coverage "(test|mocks|dependencies)" --force --report summary

COVERAGE_MIN := 100
coverage-check: ## Check if test coverage is above the minimum
	make coverage-summary | tee coverage.txt
	@coverage=$$(grep "| Total" coverage.txt | awk '{print $$4}' | sed 's/%//'); \
	if [ -z "$$coverage" ]; then \
		echo "\n❌ Failed to extract coverage percentage.\n"; \
		exit 1; \
	elif [ $$(echo "$$coverage < $(COVERAGE_MIN)" | bc -l) -eq 1 ]; then \
		echo "\n❌ Current coverage of $$coverage% below the minimum of $(COVERAGE_MIN)%.\n"; \
		exit 1; \
	else \
		echo "\n✅ Current coverage of $$coverage% meets the minimum of $(COVERAGE_MIN)%.\n"; \
	fi
	@rm coverage.txt

pre-commit: ## Run pre-commit hooks manually
	@echo && pre-commit run --all-files

docs: ## Generate documentation locally (might need to run `cargo install mdbook` first)
	@echo ">>> Cleaning old docs..."
	rm -rf docs
	@echo "\n>>> Generating documentation..."
	forge doc
	@echo "\n>>> Editing book.toml..."
	sed -i '' 's/title = ""/title = "Malda"/' ./docs/book.toml
	sed -i '' 's/authors = \[\]/authors = \["Malda"\]/' ./docs/book.toml
	sed -i '' '/\[book\]/a\'$$'\n''language = "en"' ./docs/book.toml
	sed -i '' 's/no-section-label = true/no-section-label = false/' ./docs/book.toml
	sed -i '' '/\[output.html\]/a\'$$'\n''default-theme = "dark"' ./docs/book.toml
	sed -i '' '/\[output.html\]/a\'$$'\n''preferred-dark-theme = "ayu"' ./docs/book.toml
	sed -i '' '/^\[output.html.fold\]$$/,/^\[/ s/^enable = true/enable = false/' ./docs/book.toml
	@echo "\n>>> Editing SUMMARY.md..."
	sed -i '' 's/❱ //g' ./docs/src/SUMMARY.md
	sed -i '' '/^# src$$/d' ./docs/src/SUMMARY.md
	sed -i '' 's/- \[Home\](README.md)/[README](README.md)/' ./docs/src/SUMMARY.md
	@echo "\n>>> Building book..."
	cd ./docs && mdbook build
	@echo "✅ Documentation built at ./docs/book/index.html"