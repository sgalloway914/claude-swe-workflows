REPO   := chrisallenlane/claude-swe-workflows
PLUGIN := claude-swe-workflows
CLAUDE := $(HOME)/.claude

.PHONY: help install uninstall release

## Default target - print available targets
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  install    register plugin for local development in ~/.claude/"
	@echo "  uninstall  remove plugin registration from ~/.claude/"
	@echo "  release    tag and publish a release (requires VERSION=vX.Y.Z)"

## Register the plugin for local development in ~/.claude/
install:
	@mkdir -p $(CLAUDE)/plugins
	@if [ -f $(CLAUDE)/settings.json ]; then \
		jq '.enabledPlugins["$(PLUGIN)@$(PLUGIN)"] = true' $(CLAUDE)/settings.json \
			> $(CLAUDE)/settings.json.tmp \
		&& mv $(CLAUDE)/settings.json.tmp $(CLAUDE)/settings.json; \
	else \
		printf '{"enabledPlugins":{"$(PLUGIN)@$(PLUGIN)":true}}\n' \
			| jq . > $(CLAUDE)/settings.json; \
	fi
	@TIMESTAMP=$$(date -u +%Y-%m-%dT%H:%M:%S.000Z); \
	ENTRY=$$(jq -n \
		--arg path "$(CURDIR)" \
		--arg ts "$$TIMESTAMP" \
		'{"source":{"source":"directory","path":$$path},"installLocation":$$path,"lastUpdated":$$ts}'); \
	if [ -f $(CLAUDE)/plugins/known_marketplaces.json ]; then \
		jq --argjson entry "$$ENTRY" '.["$(PLUGIN)"] = $$entry' \
			$(CLAUDE)/plugins/known_marketplaces.json \
			> $(CLAUDE)/plugins/known_marketplaces.json.tmp \
		&& mv $(CLAUDE)/plugins/known_marketplaces.json.tmp \
			$(CLAUDE)/plugins/known_marketplaces.json; \
	else \
		jq -n --argjson entry "$$ENTRY" '{"$(PLUGIN)": $$entry}' \
			> $(CLAUDE)/plugins/known_marketplaces.json; \
	fi
	@echo "Installed: $(PLUGIN) -> $(CURDIR)"

## Remove plugin registration from ~/.claude/
uninstall:
	@if [ -f $(CLAUDE)/settings.json ]; then \
		jq 'del(.enabledPlugins["$(PLUGIN)@$(PLUGIN)"])' $(CLAUDE)/settings.json \
			> $(CLAUDE)/settings.json.tmp \
		&& mv $(CLAUDE)/settings.json.tmp $(CLAUDE)/settings.json; \
	fi
	@if [ -f $(CLAUDE)/plugins/known_marketplaces.json ]; then \
		jq 'del(.["$(PLUGIN)"])' $(CLAUDE)/plugins/known_marketplaces.json \
			> $(CLAUDE)/plugins/known_marketplaces.json.tmp \
		&& mv $(CLAUDE)/plugins/known_marketplaces.json.tmp \
			$(CLAUDE)/plugins/known_marketplaces.json; \
	fi
	@echo "Uninstalled: $(PLUGIN)"

## Tag and publish a release (requires VERSION=vX.Y.Z)
release:
ifndef VERSION
	$(error VERSION is required. Usage: make release VERSION=v1.2.0)
endif
	git tag $(VERSION)
	git push origin refs/tags/$(VERSION)
	@PREV=$$(git describe --tags --abbrev=0 $(VERSION)^ 2>/dev/null); \
	if [ -n "$$PREV" ]; then \
		NOTES=$$(git log --pretty=format:'- %s' "$$PREV"..$(VERSION)); \
	else \
		NOTES=$$(git log --pretty=format:'- %s' $(VERSION)); \
	fi; \
	tea release create \
		--login gitea \
		--repo $(REPO) \
		--tag $(VERSION) \
		--title $(VERSION) \
		--note "$$NOTES"; \
	gh release create $(VERSION) \
		--repo $(REPO) \
		--title $(VERSION) \
		--notes "$$NOTES"
