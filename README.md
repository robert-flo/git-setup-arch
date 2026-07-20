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

`PKGBUILD` downloads the published `v0.1.0` release archive and verifies it with a fixed SHA-256 checksum.

## Validate the release archive

Run the release-archive validation to download the tagged archive and verify its checksum in an isolated Arch Linux container:

```bash
tests/validate-release-archive.sh
```

## Validate a local source checkout

From this package repository, run the isolated Arch Linux validation with the path to a source checkout:

```bash
GIT_SETUP_SOURCE_DIR=/path/to/git-setup---hermes-agent-era \
  tests/validate-local-install.sh
```

It creates a temporary `v0.1.0` source archive inside an `archlinux:latest` container, runs `makepkg -si` without applying the published archive checksum to that local build, and checks the installed public command. No host home directory, package cache, or installed files are changed.
