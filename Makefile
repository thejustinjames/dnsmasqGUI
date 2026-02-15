# Handed (formerly dnsmasqGUI) Makefile
# Simple commands for building and running the application

.PHONY: all build release dmg clean run help

# Default target
all: build

# Build debug version
build:
	@./scripts/build.sh Debug

# Build release version
release:
	@./scripts/build-release.sh

# Create DMG installer
dmg:
	@./scripts/build-dmg.sh

# Clean all build artifacts
clean:
	@./scripts/clean.sh

# Build and run
run:
	@./scripts/run.sh

# Show help
help:
	@echo "Handed Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make build    - Build debug version"
	@echo "  make release  - Build release version with ZIP"
	@echo "  make dmg      - Create DMG installer"
	@echo "  make clean    - Remove all build artifacts"
	@echo "  make run      - Build and run the app"
	@echo "  make help     - Show this help"
	@echo ""
	@echo "Build artifacts are placed in ./dist/"
