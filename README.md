# git-setup for Arch Linux

This repository packages [git-setup](https://github.com/robert-flo/git-setup---hermes-agent-era) for local Arch Linux installation. It installs the executable at `/usr/bin/git-setup` and its private implementation at `/opt/git-setup`.

## Install locally

Clone this package repository, build the package, and install it with pacman:

```bash
git clone <package-repository-url> git-setup
cd git-setup
makepkg -si
```

After installation, run `git-setup` to open the interactive menu. The package deliberately does not publish to AUR yet.

`PKGBUILD` downloads the matching tagged source release. Until `v0.1.0` is published, use the source checkout directly for development rather than attempting a normal package build.

## Validate a local source checkout

From this package repository, run the isolated Arch Linux validation with the path to a source checkout:

```bash
GIT_SETUP_SOURCE_DIR=/path/to/git-setup---hermes-agent-era \
  tests/validate-local-install.sh
```

It creates a temporary `v0.1.0` source archive inside an `archlinux:latest` container, runs `makepkg -si`, and checks the installed public command. No host home directory, package cache, or installed files are changed.
