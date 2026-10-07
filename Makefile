NVIM ?= nvim
FILTER ?=

.PHONY: test play dev docker-test

# Headless test suite with a local Neovim (0.12+). FILTER=test_solver runs one file.
test:
	$(NVIM) --headless -l tests/run.lua $(FILTER)

# Play in the locked-down container.
play:
	docker compose run --rm dojo

# Play the working copy without rebuilding the image.
dev:
	docker compose run --rm dev

# Run the test suite inside the pinned image.
docker-test:
	docker compose run --rm test
