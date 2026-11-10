# Common developer commands. Run `make help` for a list.
.DEFAULT_GOAL := help
.PHONY: help ios-project ios-test web-install web-test web-dev db-start db-stop db-reset db-test test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

ios-project: ## Generate apps/ios/Relo.xcodeproj from project.yml (needs xcodegen)
	cd apps/ios && xcodegen generate

ios-test: ## Run RelocDomain unit tests (needs Xcode)
	cd apps/ios/Packages/RelocKit && swift test

web-install: ## Install web dependencies
	cd apps/web && npm ci

web-test: ## Lint, typecheck and test the web app
	cd apps/web && npm run lint && npm run typecheck && npm test

web-dev: ## Run the web app at http://localhost:3000
	cd apps/web && npm run dev

db-start: ## Start local Supabase (needs a running Docker runtime, e.g. `colima start`)
	supabase start

db-stop: ## Stop local Supabase
	supabase stop

db-reset: ## Recreate the local database from migrations + seed
	supabase db reset

db-test: ## Run database lint and pgTAP tests
	supabase db lint --level warning --fail-on warning && supabase test db

test: ios-test web-test db-test ## Run every test suite
