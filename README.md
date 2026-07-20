# git-setup for Arch Linux

This repository packages [git-setup](https://github.com/robert-flo/git-setup---hermes-agent-era) for local Arch Linux installation. It installs the executable at `/usr/bin/git-setup` and its private implementation at `/opt/git-setup`.

## Install locally

Clone this package repository, build the package, and install it with pacman:

```bash
git clone <package-repository-url> git-setup
cd git-setup
make install
```

After installation, run `git-setup` to open the interactive menu. The package deliberately does not publish to AUR yet.

`make` exposes the usual package-maintenance tasks:

| Command | Action |
| --- | --- |
| `make build` | Build with `makepkg -s`. |
| `make install` | Build or reuse the existing package, then install it with `makepkg -si`. |
| `make reinstall` | Discard working build directories, force a new package, and install it with `makepkg -Cfi`. Use this after modifying `PKGBUILD` or if an existing package artifact is stale. |
| `make clean` | Remove makepkg working directories with `makepkg -c`. |
| `make lint` | Check Bash syntax, ShellCheck, `.SRCINFO`, and whitespace errors. |
| `make test-release` | Verify the published release archive in Docker. |
| `make test-local SOURCE_DIR=/path/to/source` | Build, install, and exercise a committed source checkout in Docker. |
| `make test SOURCE_DIR=/path/to/source` | Run lint and both container validations. |

Run `make help` to show this list in the terminal. `SOURCE_DIR` is the source
repository path supplied to the local validator; it is equivalent to setting
`GIT_SETUP_SOURCE_DIR` directly.

`PKGBUILD` downloads the published `v0.1.0` release archive and verifies it with a fixed SHA-256 checksum.

### Application menu launcher

The installed package also provides `git-setup.desktop` under
`/usr/share/applications`. In a graphical desktop environment it appears as
**git-setup** and opens `git-setup` in the system's default terminal emulator.
The launcher uses `Terminal=true` and the theme-provided generic terminal icon
(`utilities-terminal`); it does not start a separate graphical UI.

## Validation commands

The repository has two maintainer validations with deliberately different scopes:

| Validator | Input | Builds and installs | Public-command tests | Network source |
| --- | --- | --- | --- | --- |
| `validate-release-archive.sh` | Current `PKGBUILD` | No | No | Published GitHub tag |
| `validate-local-install.sh` | Committed `HEAD` from a source checkout | Yes, inside Docker | Yes | Temporary local archive |

Both commands run in `docker run --rm` containers. Neither command installs or upgrades host packages. They do not mount the host home directory, Git configuration, SSH keys, GPG keys, or package cache. Docker may pull and cache `archlinux:latest`, consume network bandwidth, and use disk space for the base image; the disposable container and everything installed inside it are deleted after each run.

Each script also provides complete terminal help:

```bash
tests/validate-release-archive.sh --help
tests/validate-local-install.sh --help
```

### Validate the release archive

Use this command after publishing a version tag or changing release metadata:

```bash
tests/validate-release-archive.sh
```

It performs three operations in an isolated `archlinux:latest` container:

1. Rejects `SKIP` or any malformed archive checksum in `PKGBUILD`.
2. Downloads the release archive named by `pkgver` and the other source entries.
3. Runs `makepkg --verifysource` to compare every source against its fixed checksum.

It does not build or install the package, and it does not execute `git-setup`. The stock Arch image already contains `makepkg`, `curl`, and `sha256sum`, so this validator installs no container packages and does not need `base-devel`.

The command fails when GitHub is unavailable, the version tag does not exist, a source cannot be downloaded, or any checksum differs.

### Validate a local source checkout

Use this command to prove that a particular committed source revision can be packaged, installed, and used:

```bash
GIT_SETUP_SOURCE_DIR=/path/to/git-setup---hermes-agent-era \
  tests/validate-local-install.sh
```

`GIT_SETUP_SOURCE_DIR` is mandatory because the package repository and source repository are intentionally separate. The path must identify a Git worktree containing the root `git-setup` dispatcher.

The validator performs these operations:

1. Creates a temporary, release-shaped source archive with `git archive HEAD`.
2. Starts a disposable `archlinux:latest` container with the package files and archive mounted read-only.
3. Refreshes Arch and installs only the package's exact build, installation, and runtime prerequisites.
4. Redirects the package source URL to the temporary local archive.
5. Builds and installs the package with `makepkg -si --skipchecksums`.
6. Verifies `/usr/bin/git-setup` and the private `/opt/git-setup` payload.
7. Exercises `config`, `verify`, cancelled `clean`, and the interactive menu.

The source snapshot contains committed `HEAD` only. Staged, unstaged, ignored, and untracked files are excluded by `git archive`; commit source changes before using this validator.

The local archive is not byte-identical to GitHub's generated release archive, so this check deliberately uses `--skipchecksums`. That does not weaken the release check: `validate-release-archive.sh` independently downloads the published archive and verifies its fixed checksum.

### Packages used by the local validator

The local installation check installs the following packages inside the disposable container:

- `fakeroot`, required by `makepkg` to create an Arch package as an unprivileged user.
- `sudo`, used by the builder account when `makepkg -i` invokes Pacman.
- `git`, `github-cli`, `gnupg`, `openssh`, and `git-delta`, which are the runtime dependencies declared by `PKGBUILD` and exercised by `git-setup`.

The transaction can still list dozens of packages because the runtime tools have transitive dependencies and `pacman -Syu` refreshes the rolling Arch base image. In Pacman's table, an empty **Old Version** means a new container package; both an old and new version mean the base image package is being upgraded. All reported download and installed sizes belong to the container, not to the `git-setup` package or host system.

The validator does not install `base-devel`. This package contains only Bash scripts and static templates, declares `arch=('any')`, performs no native compilation, and disables debug-package generation. The Arch base image already supplies `makepkg` and archive utilities, while `fakeroot` is the only additional packaging tool this build uses. If native compilation is added later, restore a full `base-devel` environment and update the validator documentation.

### Which command should I run?

- Normal local installation: run `makepkg -si`; the validation scripts are not required.
- Verify the published tag and checksums: run `validate-release-archive.sh`.
- Validate packaging changes or a committed source revision end to end: run `validate-local-install.sh`.
