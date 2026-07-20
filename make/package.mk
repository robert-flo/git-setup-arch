# ═══════════════════════════════════════════════════════════════
# 📦 PACKAGE WORKFLOWS - Build, install, validate, and clean
# ═══════════════════════════════════════════════════════════════
# 🎯 Purpose: Provide safe, memorable shortcuts for Arch package maintenance
# 📎 Source: SOURCE_DIR is forwarded as GIT_SETUP_SOURCE_DIR to local tests

SOURCE_DIR ?= $(GIT_SETUP_SOURCE_DIR)

.PHONY: help-package build install reinstall clean test test-release test-local lint srcinfo-check

# ═══════════════════════════════════════════════════════════════
# 📚 HELP-PACKAGE - Show package workflow targets
# ═══════════════════════════════════════════════════════════════
help-package: ## Show package maintenance targets
	@printf "$(CYAN)Package maintenance targets$(NC)\n"
	@printf "$(CYAN)────────────────────────────────────────────────────────────────────────────────$(NC)\n"
	@printf "  make build             Build the Arch package with makepkg -s\n"
	@printf "  make install           Build or reuse, then install with makepkg -si\n"
	@printf "  make reinstall         Cleanly rebuild and install with makepkg -Cfi\n"
	@printf "  make clean             Remove all local makepkg directories and artifacts\n"
	@printf "  make lint              Check Bash, ShellCheck, .SRCINFO, and whitespace\n"
	@printf "  make test-release      Verify the published release archive in Docker\n"
	@printf "  make test-local SOURCE_DIR=/path/to/source\n"
	@printf "                         Build, install, and exercise committed local source\n"
	@printf "  make test SOURCE_DIR=/path/to/source\n"
	@printf "                         Run lint and both container validations\n"
	@printf "  make srcinfo-check     Verify .SRCINFO matches PKGBUILD\n"
	@printf "\n"
	@printf "$(DIM)SOURCE_DIR is equivalent to GIT_SETUP_SOURCE_DIR. Use make reinstall after\n$(NC)"
	@printf "$(DIM)changing PKGBUILD or when an old package artifact exists.\n$(NC)"
	@printf "\n"

# ═══════════════════════════════════════════════════════════════
# 🏗️  BUILD - Create the Arch package without installing it
# ═══════════════════════════════════════════════════════════════
build: ## Build the Arch package
	@printf "\n$(CYAN)🏗️  build · creating the Arch package$(NC)\n"
	@makepkg -s

# ═══════════════════════════════════════════════════════════════
# 📥 INSTALL - Build or reuse the package, then install it
# ═══════════════════════════════════════════════════════════════
install: ## Build or reuse, then install the package
	@printf "\n$(CYAN)📥 install · building or reusing the local package$(NC)\n"
	@makepkg -si

# ═══════════════════════════════════════════════════════════════
# 🔄 REINSTALL - Force a clean build and installation
# ═══════════════════════════════════════════════════════════════
reinstall: ## Force a clean rebuild and installation
	@printf "\n$(CYAN)🔄 reinstall · forcing a clean package rebuild$(NC)\n"
	@makepkg -Cfi

# ═══════════════════════════════════════════════════════════════
# 🧹 CLEAN - Remove generated makepkg state and artifacts
# ═══════════════════════════════════════════════════════════════
clean: ## Remove all local makepkg directories and artifacts
	@printf "\n$(CYAN)🧹 clean · removing local makepkg state and artifacts$(NC)\n"
	@rm -rf -- src pkg
	@find . -maxdepth 1 -type f \( -name 'git-setup-*.pkg.tar.*' -o -name 'git-setup-*.tar.gz' \) -delete
	@printf "$(GREEN)  ✓ checkout is ready for a fresh package build$(NC)\n"

# ═══════════════════════════════════════════════════════════════
# 🔎 LINT - Check package metadata and shell quality
# ═══════════════════════════════════════════════════════════════
lint: srcinfo-check ## Check scripts, metadata, and whitespace
	@printf "\n$(CYAN)🔎 lint · checking scripts, metadata, and whitespace$(NC)\n"
	@bash -n tests/*.sh tests/lib/*.sh
	@shellcheck tests/*.sh tests/lib/*.sh
	@git diff --check
	@printf "$(GREEN)  ✓ lint passed$(NC)\n"

# ═══════════════════════════════════════════════════════════════
# 📄 SRCINFO-CHECK - Keep generated metadata in sync
# ═══════════════════════════════════════════════════════════════
srcinfo-check: ## Verify .SRCINFO matches PKGBUILD
	@cmp .SRCINFO <(makepkg --printsrcinfo)

# ═══════════════════════════════════════════════════════════════
# 🌐 TEST-RELEASE - Verify the published release archive
# ═══════════════════════════════════════════════════════════════
test-release: ## Verify the published release archive in Docker
	@tests/validate-release-archive.sh

# ═══════════════════════════════════════════════════════════════
# 🧪 TEST-LOCAL - Build and exercise a local source revision
# ═══════════════════════════════════════════════════════════════
test-local: ## Validate a local source checkout in Docker
	@test -n "$(SOURCE_DIR)" || { \
		printf '$(RED)ERROR: set SOURCE_DIR=/path/to/git-setup source checkout.$(NC)\n' >&2; \
		exit 2; \
	}
	@GIT_SETUP_SOURCE_DIR="$(SOURCE_DIR)" tests/validate-local-install.sh

# ═══════════════════════════════════════════════════════════════
# ✅ TEST - Run every package validation
# ═══════════════════════════════════════════════════════════════
test: lint test-release test-local ## Run lint and both package validations
