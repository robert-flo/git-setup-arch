#!/usr/bin/env bash

set -Eeuo pipefail

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${GIT_SETUP_SOURCE_DIR:-}"

if [[ -z "$source_dir" || ! -f "$source_dir/git-setup" ]]; then
  printf '%s\n' 'Set GIT_SETUP_SOURCE_DIR to a git-setup source checkout.' >&2
  exit 2
fi

archive_dir="$(mktemp -d "${TMPDIR:-/tmp}/git-setup-package.XXXXXX")"
trap 'rm -rf "$archive_dir"' EXIT
archive_path="$archive_dir/git-setup-0.1.0.tar.gz"
chmod 0755 "$archive_dir"

git -C "$source_dir" archive --format=tar.gz \
  --prefix=git-setup---hermes-agent-era-0.1.0/ \
  HEAD > "$archive_path"

docker run --rm \
  --volume "$package_dir:/package:ro" \
  --volume "$archive_dir:/archive:ro" \
  archlinux:latest \
  bash -Eeuo pipefail -c '
    pacman -Syu --noconfirm --needed base-devel sudo git github-cli gnupg openssh git-delta

    useradd --create-home builder
    printf "builder ALL=(ALL) NOPASSWD: ALL\\n" > /etc/sudoers.d/builder
    chmod 0440 /etc/sudoers.d/builder

    install -d -m 0755 /work/package
    cp -a /package/. /work/package/
    sed -i \
      "s|\${url}/archive/refs/tags/v\${pkgver}.tar.gz|file:///archive/git-setup-0.1.0.tar.gz|" \
      /work/package/PKGBUILD
    chown -R builder:builder /work/package

    su --shell /bin/bash builder --command \
      "cd /work/package && makepkg -si --noconfirm --needed --skipchecksums"

    test -x /usr/bin/git-setup
    test -x /opt/git-setup/git-setup
    HOME=/tmp/git-setup-package-test \
      NAME="Package Test" \
      EMAIL="package-test@example.com" \
      TERM=dumb \
      /usr/bin/git-setup config > /tmp/git-setup-package-output
    test "$(git config --file /tmp/git-setup-package-test/.config/git/config --get user.name)" = "Package Test"
    test "$(git config --file /tmp/git-setup-package-test/.config/git/config --get core.pager)" = delta
    grep -Fq "Git Configuration Files" /tmp/git-setup-package-output

    HOME=/tmp/git-setup-package-test TERM=dumb /usr/bin/git-setup verify \
      > /tmp/git-setup-package-verify-output || true
    grep -Fq "Generated Git Configuration Files" /tmp/git-setup-package-verify-output

    printf "no\\n" | HOME=/tmp/git-setup-package-test TERM=dumb /usr/bin/git-setup clean \
      > /tmp/git-setup-package-clean-output
    grep -Fq "Cancelled" /tmp/git-setup-package-clean-output
    test -f /tmp/git-setup-package-test/.config/git/config

    printf "q\\n" | HOME=/tmp/git-setup-package-test TERM=dumb /usr/bin/git-setup \
      > /tmp/git-setup-package-menu-output
    grep -Fq "Choose an action" /tmp/git-setup-package-menu-output
  '

printf '%s\n' 'PASS: local Arch package installation and public command validation'
