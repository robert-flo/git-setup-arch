.PHONY: help build install reinstall clean test test-release test-local lint srcinfo-check

SOURCE_DIR ?= $(GIT_SETUP_SOURCE_DIR)

help:
	@printf '%s\n' '' \
	  'git-setup package commands' \
	  '──────────────────────────' \
	  '  make build             Build the Arch package (makepkg -s).' \
	  '  make install           Build or reuse, then install (makepkg -si).' \
	  '  make reinstall         Cleanly rebuild and install (makepkg -Cfi).' \
	  '  make clean             Remove local makepkg working directories (src/ and pkg/).' \
	  '  make lint              Check Bash syntax, ShellCheck, PKGBUILD metadata, and whitespace.' \
	  '  make test-release      Verify the published release archive in Docker.' \
	  '  make test-local SOURCE_DIR=/path/to/source' \
	  '                         Build/install a committed source revision in Docker.' \
	  '  make test SOURCE_DIR=/path/to/source' \
	  '                         Run both package validations.' \
	  '  make srcinfo-check     Verify .SRCINFO matches PKGBUILD.' \
	  '' \
	  'SOURCE_DIR is an alias for GIT_SETUP_SOURCE_DIR used by the local test.' \
	  'Use make reinstall after changing PKGBUILD or when an old package artifact exists.' \
	  ''

build:
	makepkg -s

install:
	makepkg -si

reinstall:
	makepkg -Cfi

clean:
	rm -rf -- src pkg

lint: srcinfo-check
	bash -n tests/*.sh tests/lib/*.sh
	shellcheck tests/*.sh tests/lib/*.sh
	git diff --check

srcinfo-check:
	cmp .SRCINFO <(makepkg --printsrcinfo)

test-release:
	tests/validate-release-archive.sh

test-local:
	@test -n "$(SOURCE_DIR)" || { \
		printf '%s\n' 'ERROR: set SOURCE_DIR=/path/to/git-setup source checkout.' >&2; \
		exit 2; \
	}
	GIT_SETUP_SOURCE_DIR="$(SOURCE_DIR)" tests/validate-local-install.sh

test: lint test-release test-local
